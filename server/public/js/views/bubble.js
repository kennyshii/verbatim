import { effectiveKind, isJudged, isMultiplayer, modeInfo, questionsIn } from "../data.js";
import { parseFeedback } from "../feedback.js";
import { analyze, overall } from "../metrics.js";
import { feedbackSections, h, icon, readAloudButton, richText } from "../ui.js";

export function messageBubble(message, mode, { language = "English", showMetrics = false } = {}) {
  const kind = effectiveKind(message);
  const isUser = message.role === "user";
  const procedural = kind === "inquiry" || kind === "ruling";
  const humanSpeech = !procedural && (isUser || (isJudged(mode) && message.role === "assistant"));
  const label = message.speaker && (isMultiplayer(mode) || mode === "Congress")
    ? message.speaker
    : isUser ? "You" : modeInfo(mode).assistantLabel;

  const tagged = (iconName, text, body) => [h("div", { class: "bubble-tag" }, icon(iconName), text), body];

  let body;
  if (procedural) {
    body = tagged(kind === "inquiry" ? "hand" : "gavel", kind === "inquiry" ? "Point of inquiry" : "The chair rules", richText(message.text));
  } else if (kind === "amendment") {
    body = tagged("amend", "Amendment", richText(message.text));
  } else if (kind === "crossfireQuestion") {
    body = tagged("question", "Crossfire",
      h("ol", { class: "crossfire-list" }, questionsIn(message.text).map((q) => h("li", null, q))));
  } else if (message.role === "assistant" && mode === "Coach") {
    body = feedbackSections(parseFeedback(message.text), { compact: true, language });
  } else {
    body = richText(message.text);
  }

  let metricsLine = null;
  if (showMetrics && humanSpeech) {
    const m = analyze(message.text);
    metricsLine = h("div", { class: "bubble-metrics" },
      `${overall(m)}% · ${m.fillerCount} filler${m.fillerCount === 1 ? "" : "s"} · ${m.toneLabel.toLowerCase()}`);
  }

  return h("div", { class: `bubble-row${isUser ? " mine" : ""}` },
    h("article", { class: `bubble${isUser ? " mine" : ""}${procedural ? " procedural" : ""}` },
      h("div", { class: "bubble-head" },
        h("span", { class: "bubble-speaker" }, kind === "crossfireAnswer" ? `${label} · crossfire answer` : label),
        humanSpeech ? null : readAloudButton(message.text, language)),
      body,
      metricsLine,
      message.statCheck ? h("div", { class: "stat-check" },
        h("div", { class: "bubble-tag" }, icon("shield"), "Stat check"),
        richText(message.statCheck)) : null));
}
