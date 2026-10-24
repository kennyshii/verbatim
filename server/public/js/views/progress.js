import { isJudged } from "../data.js";
import { recurringTags } from "../feedback.js";
import { analyzeTurns, overall } from "../metrics.js";
import * as store from "../store.js";
import { formatDate, h, meterBar, navRow, pageHeader, sectionLabel, statTile, subtext, topicBox } from "../ui.js";
import { messageBubble } from "./bubble.js";
import { resultView } from "./feedback.js";
import { averageAccuracy, ownTurns } from "./home.js";

const empty = (text) => h("div", { class: "card empty" }, text);

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
          statTile(String(streak.current), "Current streak", "flame"),
          statTile(String(streak.longest), "Longest streak", "trophy"),
          statTile(String(sessions.length), "Sessions", "checkCircle"),
          statTile(accuracy === null ? "—" : `${accuracy}%`, "Avg. accuracy", "wave2")),
        subtext("Streak counts consecutive days with at least one completed session. Presentational accuracy blends filler words (−5 each), smoothness, and tone.")),
      h("section", { class: "stack" },
        sectionLabel("Recurring feedback"),
        sessions.length < 2
          ? empty("Complete at least two sessions to see patterns in your feedback.")
          : tags.length
            ? tags.map((t) => h("div", { class: "card tag-row" }, h("strong", null, t.name), h("span", { class: "subtext small" }, `flagged in ${t.count} sessions`)))
            : empty("No recurring themes yet.")),
      h("section", { class: "stack" },
        sectionLabel("Past sessions"),
        sessions.length
          ? sessions.map((s) => navRow({
              iconName: s.kind === "congress" ? "congress" : "debate",
              title: s.topic,
              detail: `${formatDate(s.createdAt)} · ${s.mode} · ${overall(analyzeTurns(ownTurns(s)))}%`,
              href: `#/progress/${s.id}`,
            }))
          : empty("No sessions yet."))));
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
      session.feedback ? resultView(session.feedback, config) : subtext("No feedback was saved for this session."),
      h("section", { class: "card stack" }, sectionLabel("Delivery"), meterBar(analyzeTurns(ownTurns(session)))),
      h("h2", { class: "accent-heading" }, "Transcript"),
      h("div", { class: "transcript" }, session.transcript.map((m) => messageBubble(m, session.mode, { language: session.language })))));
  return { el, title: "Session" };
}
