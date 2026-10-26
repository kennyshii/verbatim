import { isJudged } from "../data.js";
import { recurringTags } from "../feedback.js";
import { analyzeTurns } from "../metrics.js";
import * as store from "../store.js";
import { formatDate, h, meterBar, navRow, pageHeader, sectionLabel, statTile, topicBox } from "../ui.js";
import { messageBubble } from "./bubble.js";
import { resultView } from "./feedback.js";
import { averageAccuracy, ownTurns } from "./home.js";

const empty = (text) => h("div", { class: "card empty" }, text);

function bestLines(sessions) {
  const lines = [];
  for (const session of sessions) {
    if (session.feedback?.type !== "coach") continue;
    const match = String(session.feedback.feedback.strongestArgument).match(/[“"]([^”"\n]{12,220}?)[”"]/);
    if (match) lines.push({ quote: match[1], source: `${session.topic.replace(/^Resolved:\s*/, "")} · ${formatDate(session.createdAt).split(",")[0]}`, id: session.id });
    if (lines.length === 6) break;
  }
  return lines;
}

export function progressView({ app }) {
  const streak = store.streak(app.user.id);
  const sessions = store.sessionsFor(app.user.id);
  const tags = recurringTags(sessions);
  const accuracy = averageAccuracy(sessions);

  const el = h("div", { class: "page" },
    pageHeader({ title: "Progress" }),
    h("div", { class: "stack-xl" },
      h("div", { class: "stack" },
        h("div", { class: "tiles" },
          statTile(String(streak.current), "Current streak", "flame", 0),
          statTile(String(streak.longest), "Longest streak", "trophy", 1),
          statTile(String(sessions.length), "Rounds", "checkCircle", 2),
          statTile(accuracy === null ? "—" : `${accuracy}%`, "Avg. delivery", "wave2", 3))),
      (() => {
        const lines = bestLines(sessions);
        return lines.length ? h("section", { class: "stack reveal" },
          sectionLabel("Lines worth keeping"),
          h("div", { class: "lines-row" }, lines.map((l) => h("a", { class: "card line-card", href: `#/progress/${l.id}` },
            h("q", { class: "verbatim" }, h("mark", null, l.quote)),
            h("span", { class: "subtext small" }, l.source))))) : null;
      })(),
      h("section", { class: "stack reveal" },
        sectionLabel("Keep working on"),
        sessions.length < 2
          ? empty("Complete at least two sessions to see patterns in your feedback.")
          : tags.length
            ? h("div", { class: "group" }, tags.map((t) => h("div", { class: "card tag-row" }, h("strong", null, t.name), h("span", { class: "subtext small" }, `flagged in ${t.count} of ${sessions.length} rounds`))))
            : empty("No recurring themes yet.")),
      h("section", { class: "stack reveal" },
        sectionLabel("Rounds"),
        sessions.length
          ? h("div", { class: "group" }, sessions.map((s) => navRow({
              iconName: s.kind === "congress" ? "congress" : "debate",
              title: s.topic,
              href: `#/progress/${s.id}`,
            })))
          : empty("No rounds yet. Finish one and it shows up here."))));
  return { el, title: "Progress" };
}

export function sessionDetailView({ params, app }) {
  const session = store.sessionById(app.user.id, Number(params[0]));
  if (!session) {
    queueMicrotask(() => app.go("/progress"));
    return { el: h("div") };
  }
  const config = { ...session, participants: session.participants || [] };

  const el = h("div", { class: "page narrow" },
    pageHeader({ title: "Session", back: { href: "#/progress", label: "Progress" } }),
    h("div", { class: "stack-lg" },
      topicBox(session.kind === "congress" ? session.committee || "Legislation" : "Resolution", session.topic,
        `${formatDate(session.createdAt)} · ${session.mode} · ${session.difficulty} · ${session.language}`),
      h("h2", { class: "accent-heading" }, isJudged(session.mode) ? "Decision" : "Feedback"),
      session.feedback ? resultView(session.feedback, config) : h("p", null, "No feedback was saved for this session."),
      h("section", { class: "card stack" }, sectionLabel("Delivery"), meterBar(analyzeTurns(ownTurns(session)))),
      h("h2", { class: "accent-heading" }, "Transcript"),
      h("div", { class: "transcript" }, session.transcript.map((m) => messageBubble(m, session.mode, { language: session.language })))));
  return { el, title: "Session" };
}
