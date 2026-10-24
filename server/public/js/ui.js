import { sectionTitles } from "./data.js";
import * as M from "./metrics.js";
import { speak } from "./speech.js";

export function h(tag, attrs, ...children) {
  const el = document.createElement(tag);
  if (attrs) {
    for (const [key, value] of Object.entries(attrs)) {
      if (value === null || value === undefined || value === false) continue;
      if (key.startsWith("on") && typeof value === "function") el.addEventListener(key.slice(2).toLowerCase(), value);
      else if (key === "class") el.className = value;
      else if (key === "style" && typeof value === "object") Object.assign(el.style, value);
      else if (key === "value") el.value = value;
      else if (value === true) el.setAttribute(key, "");
      else el.setAttribute(key, value);
    }
  }
  append(el, children);
  return el;
}

function append(el, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
}

export function replace(el, ...children) {
  el.replaceChildren();
  append(el, children);
  return el;
}

const ICONS = {
  debate: '<path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/>',
  coach: '<path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/>',
  versus: '<circle cx="9" cy="7" r="4"/><path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/><path d="M21 21v-2a4 4 0 0 0-3-3.9"/>',
  twoVtwo: '<circle cx="12" cy="7" r="3"/><circle cx="5" cy="9" r="2.5"/><circle cx="19" cy="9" r="2.5"/><path d="M7 21v-2a5 5 0 0 1 10 0v2"/><path d="M1 21v-1.5A3.5 3.5 0 0 1 4.5 16"/><path d="M23 21v-1.5a3.5 3.5 0 0 0-3.5-3.5"/>',
  team: '<circle cx="9" cy="7" r="4"/><path d="M3 21v-2a4 4 0 0 1 4-4h4"/><circle cx="18" cy="17" r="3"/><path d="M18 12v2M18 20v2M13 17h2M21 17h2"/>',
  congress: '<path d="M3 22h18"/><path d="M6 18v-7M10 18v-7M14 18v-7M18 18v-7"/><path d="m12 2 8 5H4z"/>',
  chart: '<path d="M3 3v18h18"/><path d="M8 17v-5M13 17V8M18 17v-9"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  back: '<path d="m15 18-6-6 6-6"/>',
  quote: '<path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/>',
  hash: '<path d="M4 9h16M4 15h16M10 3 8 21M16 3l-2 18"/>',
  key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>',
  leaf: '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/>',
  flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
  bolt: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
  mic: '<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10v1a7 7 0 0 1-14 0v-1M12 18v4"/>',
  hand: '<path d="M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
  speaker: '<path d="M11 5 6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07M19.07 4.93a10 10 0 0 1 0 14.14"/>',
  link: '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  external: '<path d="M15 3h6v6M10 14 21 3M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
  check: '<path d="M20 6 9 17l-5-5"/>',
  crown: '<path d="m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7zM5 20h14"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1"/>',
  clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  upload: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M12 18v-6M9 15l3-3 3 3"/>',
  flag: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7"/>',
  heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
  question: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><path d="M9.5 8.5a2.5 2.5 0 0 1 5 .5c0 1.5-2.5 2-2.5 3.5M12 14.5h.01"/>',
  rosette: '<circle cx="12" cy="8" r="6"/><path d="M15.477 12.89 17 22l-5-3-5 3 1.523-9.11"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
  wave: '<path d="M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
  pencil: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
  doc: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/>',
  rebut: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
  device: '<rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/>',
  wifi: '<path d="M5 12.55a11 11 0 0 1 14.08 0M1.42 9a16 16 0 0 1 21.16 0M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01"/>',
  trophy: '<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6M18 9h1.5a2.5 2.5 0 0 0 0-5H18M4 22h16M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22M18 2H6v7a6 6 0 0 0 12 0V2Z"/>',
  wave2: '<path d="M2 12h2M6 8v8M10 5v14M14 9v6M18 7v10M22 12h-2"/>',
  info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
  close: '<path d="M18 6 6 18M6 6l12 12"/>',
  share: '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8M16 6l-4-4-4 4M12 2v13"/>',
  sparkle: '<path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/>',
  gavel: '<path d="m14 13-7.5 7.5a2.12 2.12 0 0 1-3-3L11 10M16 16l6-6M8 8l6-6M9 7l8 8M21 11l-8-8"/>',
  amend: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M12 18v-6M9 15h6"/>',
  circle: '<circle cx="12" cy="12" r="9"/>',
  checkCircle: '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
};

export function icon(name, cls = "icon") {
  const span = document.createElement("span");
  span.className = cls;
  span.setAttribute("aria-hidden", "true");
  span.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ICONS.circle}</svg>`;
  return span;
}

export function richText(text, cls = "rich") {
  const el = h("div", { class: cls });
  const parts = String(text).replace(/^#{1,6}\s+/gm, "").split(/\*\*(.+?)\*\*/g);
  parts.forEach((part, i) => el.append(i % 2 ? h("strong", null, part) : document.createTextNode(part)));
  return el;
}

export const sectionLabel = (text) => h("div", { class: "section-label" }, text);
export const subtext = (text, cls = "") => h("p", { class: `subtext ${cls}` }, text);

export function chip({ label, iconName, selected, onClick }) {
  return h("button", { type: "button", class: `chip${selected ? " selected" : ""}`, "aria-pressed": selected ? "true" : "false", onClick },
    iconName ? icon(iconName) : null, label);
}

export function optionCard({ title, subtitle, iconName, selected, onClick }) {
  return h("button", { type: "button", class: `option-card${selected ? " selected" : ""}`, "aria-pressed": selected ? "true" : "false", onClick },
    iconName ? h("span", { class: "option-icon" }, icon(iconName)) : null,
    h("span", { class: "option-body" },
      h("span", { class: "option-title" }, title),
      subtitle ? h("span", { class: "subtext" }, subtitle) : null),
    icon(selected ? "checkCircle" : "circle", "icon option-check"));
}

export function navRow({ iconName, title, badge, detail, href, onClick, clamp = true }) {
  return h(href ? "a" : "button", { class: "nav-row card", href, type: href ? null : "button", onClick },
    h("span", { class: "row-icon" }, icon(iconName)),
    h("span", { class: "row-body" },
      h("span", { class: "row-title" }, title),
      badge ? h("span", { class: "row-badge" }, badge) : null,
      detail ? h("span", { class: `subtext${clamp ? " clamp" : ""}` }, detail) : null),
    icon("chevron", "icon row-chevron"));
}

export function readAloudButton(text, language) {
  return h("button", { type: "button", class: "icon-button", title: "Read aloud", "aria-label": "Read aloud", onClick: () => speak(text, language) }, icon("speaker"));
}

const level = (value) => (value >= 90 ? "good" : value >= 75 ? "ok" : "low");

function bar(value) {
  return h("div", { class: `bar ${level(value)}`, role: "meter", "aria-valuemin": "0", "aria-valuemax": "100", "aria-valuenow": String(value) },
    h("div", { class: "bar-fill", style: { width: `${value}%` } }));
}

export function meterBar(metrics, { title = "Presentational accuracy", compact = false } = {}) {
  const total = M.overall(metrics);
  const row = (label, value, note) => h("div", { class: "meter-row" },
    h("span", { class: "meter-label" }, label), bar(value), h("span", { class: `meter-value ${level(value)}` }, String(value)),
    compact ? null : h("span", { class: "meter-note" }, note));
  return h("div", { class: `meter${compact ? " compact" : ""}` },
    h("div", { class: "meter-head" }, h("span", null, title), h("span", { class: `meter-total ${level(total)}` }, `${total}%`)),
    bar(total),
    row("Filler words", metrics.fillerScore, M.fillerSummary(metrics)),
    row("Smoothness", metrics.smoothness, M.smoothnessSummary(metrics)),
    row("Tone", metrics.tone, M.toneSummary(metrics)));
}

export function feedbackSections(feedback, { kind = "debate", compact = false, language = "English" } = {}) {
  const titles = sectionTitles(kind);
  const bodies = [feedback.strongestArgument, feedback.weakestArgument, feedback.missedRebuttal, feedback.suggestion];
  return h("div", { class: `feedback-list${compact ? " compact" : ""}` },
    titles.map((title, i) => h("section", { class: compact ? "feedback-item" : "feedback-item card" },
      h("div", { class: "feedback-head" }, h("h3", null, title), compact ? null : readAloudButton(`${title}. ${bodies[i]}`, language)),
      richText(bodies[i]))));
}

export function judgeDecision(decision, { affirmative, negative, language = "English" }) {
  const sections = [
    ["Reason for decision", decision.reasonForDecision],
    [`Feedback for ${affirmative} (Affirmative)`, decision.affirmativeFeedback],
    [`Feedback for ${negative} (Negative)`, decision.negativeFeedback],
  ];
  return h("div", { class: "feedback-list" },
    h("section", { class: "card sand decision" },
      h("div", { class: "feedback-head" },
        h("h3", { class: "decision-label" }, icon("rosette"), "Decision"),
        readAloudButton(`Decision: ${decision.winner}. ${decision.reasonForDecision}`, language)),
      h("p", { class: "decision-winner" }, decision.winner)),
    sections.map(([title, body]) => h("section", { class: "feedback-item card" },
      h("div", { class: "feedback-head" }, h("h3", null, title), readAloudButton(`${title}. ${body}`, language)),
      richText(body))));
}

export function statTile(value, label, iconName) {
  return h("div", { class: "stat-tile card" }, icon(iconName, "icon accent"), h("div", { class: "stat-value" }, value), h("div", { class: "subtext" }, label));
}

export function modal(title, build) {
  const close = () => { dialog.close(); dialog.remove(); };
  const dialog = h("dialog", { class: "modal", "aria-label": title });
  dialog.append(
    h("div", { class: "modal-head" }, h("h2", null, title),
      h("button", { type: "button", class: "icon-button", "aria-label": "Close", onClick: close }, icon("close"))),
    h("div", { class: "modal-body" }, build(close)));
  dialog.addEventListener("cancel", (e) => { e.preventDefault(); close(); });
  dialog.addEventListener("click", (e) => { if (e.target === dialog) close(); });
  document.body.append(dialog);
  dialog.showModal();
  return close;
}

export function confirmDialog(title, confirmLabel, onConfirm) {
  modal(title, (close) => h("div", { class: "stack" },
    h("button", { type: "button", class: "button primary", onClick: () => { close(); onConfirm(); } }, confirmLabel),
    h("button", { type: "button", class: "button secondary", onClick: close }, "Keep going")));
}

export function autoGrow(textarea, max = 220) {
  const fit = () => { textarea.style.height = "auto"; textarea.style.height = `${Math.min(textarea.scrollHeight, max)}px`; };
  textarea.addEventListener("input", fit);
  requestAnimationFrame(fit);
  return fit;
}

export function pageHeader({ title, back, actions = [] }) {
  return h("div", { class: "page-header" },
    back ? h("a", { class: "back-link", href: back.href, onClick: back.onClick }, icon("back"), back.label || "Back") : h("span"),
    h("h1", null, title),
    h("div", { class: "page-actions" }, actions));
}

export function topicBox(label, topic, meta) {
  return h("div", { class: "topic-box" },
    h("div", { class: "subtext small" }, label),
    h("div", { class: "topic-text" }, topic),
    meta ? (meta instanceof Node ? meta : h("div", { class: "subtext small" }, meta)) : null);
}

export function formatDate(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toLocaleString(undefined, { month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" });
}
