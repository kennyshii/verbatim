import { DEBATE_MODES, SUGGESTED_RESOLUTIONS, modeInfo } from "../data.js";
import { analyzeTurns, overall } from "../metrics.js";
import * as store from "../store.js";
import { h, icon, modal, navRow, replace, sectionLabel } from "../ui.js";
import { joinForm } from "./online.js";

export const ownTurns = (session) => session.transcript.filter((m) => m.role === "user").map((m) => m.text);

export function averageAccuracy(sessions) {
  const totals = sessions.map((s) => analyzeTurns(ownTurns(s))).filter((m) => m.wordCount > 0).map(overall);
  return totals.length ? Math.floor(totals.reduce((a, b) => a + b, 0) / totals.length) : null;
}

export function aiWarning(app) {
  return app.ai.ready ? null : h("div", { class: "card sand notice" }, icon("key"),
    h("span", null, "The server has no Anthropic API key yet. Add ANTHROPIC_API_KEY to server/.env and restart it to start a round."));
}

export default function homeView({ app }) {
  const streak = store.streak(app.user.id);
  const sessions = store.sessionsFor(app.user.id);
  const accuracy = averageAccuracy(sessions);
  const active = streak.current > 0;

  const metric = (label, value) => h("div", { class: "metric" }, h("div", { class: "metric-value" }, value), h("div", { class: "subtext small" }, label));

  const statusCard = h("section", { class: "card status-card" },
    h("div", { class: "status-line" },
      h("span", { class: `dot${active ? " on" : ""}` }),
      h("span", { class: `status-text${active ? " on" : ""}` }, active ? "Streak active" : "No active streak"),
      h("span", { class: "subtext small push" }, app.user.username)),
    h("h1", { class: "status-title" }, active ? `${streak.current}-day streak` : "Ready to practice"),
    h("div", { class: "metrics" },
      metric("Sessions", String(sessions.length)),
      metric("Longest", `${streak.longest}d`),
      metric("Accuracy", accuracy === null ? "—" : `${accuracy}%`)),
    h("a", { class: "button primary", href: "#/debate/setup" }, "Start a debate"));

  const warning = h("div");
  const showWarning = () => replace(warning, aiWarning(app));
  showWarning();

  const el = h("div", { class: "page home" },
    h("div", { class: "home-grid" },
      h("div", { class: "stack-lg" },
        statusCard,
        h("section", { class: "stack" },
          sectionLabel("Practice modes"),
          DEBATE_MODES.map((id) => {
            const mode = modeInfo(id);
            return navRow({ iconName: mode.icon, title: id, detail: mode.explanation, href: `#/debate/setup?mode=${encodeURIComponent(id)}` });
          }))),
      h("div", { class: "stack-lg" },
        h("section", { class: "stack" },
          sectionLabel("Suggested resolutions"),
          SUGGESTED_RESOLUTIONS.map((r) => h("a", { class: "card resolution-row", href: `#/debate/setup?topic=${encodeURIComponent(r)}` },
            icon("quote", "icon accent small-icon"), h("span", null, r), icon("chevron", "icon row-chevron")))),
        h("button", { type: "button", class: "button secondary", onClick: () => modal("Join a round", (close) => joinForm(app, (code) => { close(); app.go(`/room/${code}`); })) },
          icon("hash"), "Join a round with a code"),
        warning)));

  return { el, title: "Debate", onStatus: showWarning };
}
