import { DEBATE_MODES, FEATURED_RESOLUTION, SUGGESTED_RESOLUTIONS, modeInfo } from "../data.js";
import { analyzeTurns, overall } from "../metrics.js";
import { gallery, trackProgress } from "../motion.js";
import * as store from "../store.js";
import { h, icon, maskWords, modal, replace } from "../ui.js";
import { joinForm } from "./online.js";

export const ownTurns = (session) => session.transcript.filter((m) => m.role === "user").map((m) => m.text);

export function averageAccuracy(sessions) {
  const totals = sessions.map((s) => analyzeTurns(ownTurns(s))).filter((m) => m.wordCount > 0).map(overall);
  return totals.length ? Math.floor(totals.reduce((a, b) => a + b, 0) / totals.length) : null;
}

export function aiWarning(app) {
  return app.ai.ready ? null : h("div", { class: "notice" }, icon("key"),
    h("span", null, "The server has no Anthropic API key yet. Add ANTHROPIC_API_KEY to server/.env and restart it to start a round."));
}

export function currentResolution() {
  return FEATURED_RESOLUTION;
}

const MODE_LINES = {
  Debate: ["Argue it out.", "The AI takes the other side and pushes back on every weak link, live."],
  Coach: ["Get coached.", "No opponent. Structured, honest feedback after every single speech."],
  "1v1": ["Face a friend.", "Same device or online with a code. An AI judge writes the ballot."],
  "2v2": ["Bring a team.", "Public Forum, two on two. First speakers build, second speakers rebut."],
  "Team vs AI": ["Partner up.", "You and a partner against an AI team, with live crossfire."],
};

function greeting() {
  const hour = new Date().getHours();
  return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
}

export default function homeView({ app }) {
  const streak = store.streak(app.user.id);
  const sessions = store.sessionsFor(app.user.id);
  const accuracy = averageAccuracy(sessions);
  const featured = currentResolution();
  const setupFor = (topic) => `#/debate/setup?topic=${encodeURIComponent(topic)}`;

  const warning = h("div");
  const showWarning = () => replace(warning, aiWarning(app));
  showWarning();

  const featureTile = h("section", { class: "feature-tile reveal" },
    h("span", { class: "eyebrow" }, featured.label),
    h("p", { class: "featured-resolution" }, featured.text),
    h("div", { class: "hero-actions" },
      h("a", { class: "button primary", href: setupFor(featured.text) }, "Practice this resolution"),
      h("a", { class: "more-link", href: "#/debate/setup" }, "Choose another", icon("chevron"))));
  const stopTracking = trackProgress(featureTile, {
    onProgress: (p) => featureTile.style.setProperty("--p", Math.min(1, p * 2.2).toFixed(3)),
  });

  const modeCards = DEBATE_MODES.map((id) => {
    const mode = modeInfo(id);
    const [headline, line] = MODE_LINES[id];
    return h("a", { class: "mode-card", href: `#/debate/setup?mode=${encodeURIComponent(id)}` },
      h("span", { class: "mode-glyph" }, icon(mode.icon)),
      h("span", { class: "eyebrow" }, id),
      h("h3", null, headline),
      h("p", null, line),
      h("span", { class: "more-link" }, "Start", icon("chevron")));
  });

  const resolutionCards = SUGGESTED_RESOLUTIONS.filter((r) => r !== featured.text).map((r) =>
    h("a", { class: "resolution-card", href: setupFor(r) },
      h("p", null, r),
      h("span", { class: "more-link" }, "Practice", icon("chevron"))));

  const tile = (iconName, value, label, i) => h("div", { class: "bento-tile reveal", style: { "--i": i } },
    icon(iconName), h("div", { class: "big" }, value), h("div", { class: "subtext" }, label));

  const el = h("div", { class: "page home" },
    h("header", { class: "hero" },
      h("span", { class: "streak-pill reveal" }, icon("flame"), streak.current > 0 ? `${streak.current}-day streak` : "Start a streak today"),
      h("h1", { class: "words reveal", style: { "--i": 1 } }, maskWords(`${greeting()}, ${app.user.username}.`)),
      h("p", { class: "lede reveal", style: { "--i": 2 } }, "Need help organizing your thoughts? We’ll help you visualize it.")),
    h("div", { class: "stack-xl", style: { marginTop: "48px" } },
      featureTile,
      warning,
      h("section", { class: "stack reveal" },
        h("div", { class: "section-head" }, h("h2", null, "Ways to practice.")),
        gallery(modeCards, { label: "Practice modes" })),
      h("section", { class: "stack reveal" },
        h("div", { class: "section-head" }, h("h2", null, "More resolutions."), h("a", { class: "more-link", href: "#/debate/setup" }, "All topics", icon("chevron"))),
        gallery(resolutionCards, { label: "Resolutions" })),
      h("section", { class: "stack" },
        h("div", { class: "section-head reveal" }, h("h2", null, "Your numbers."), h("a", { class: "more-link", href: "#/progress" }, "See progress", icon("chevron"))),
        h("div", { class: "bento" },
          tile("checkCircle", String(sessions.length), "Rounds finished", 0),
          tile("trophy", `${streak.longest}d`, "Longest streak", 1),
          tile("wave2", accuracy === null ? "—" : `${accuracy}%`, "Average delivery", 2))),
      h("section", { class: "feature-tile light reveal" },
        h("span", { class: "eyebrow" }, "Play a friend"),
        h("h2", { class: "accent-heading" }, "Got a room code?"),
        h("p", { class: "subtext", style: { fontSize: "19px" } }, "Join a round someone else started. No account needed on their end."),
        h("button", { type: "button", class: "button primary", style: { width: "auto" }, onClick: () => modal("Join a round", (close) => joinForm(app, (code) => { close(); app.go(`/room/${code}`); })) },
          icon("hash"), "Join a round"))));

  return { el, title: "Debate", onStatus: showWarning, destroy: stopTracking };
}
