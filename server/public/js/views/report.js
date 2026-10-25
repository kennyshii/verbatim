import { containsStatistic } from "../metrics.js";
import { reduceMotion } from "../motion.js";
import { dictation } from "../speech.js";
import { autoGrow, h, icon, modal, replace, subtext } from "../ui.js";

export const DEMO_DELIVERY = [
  ["Delivery", 84, "Steady 148 words a minute"],
  ["Pronunciation", 86, "One word clipped"],
  ["Filler words", 78, "Three “um”s"],
  ["Gaps in thought", 76, "Two pauses over 2 seconds"],
];

export const DEMO_MAP = {
  claim: "The U.S. has a moral obligation to ensure that full-time workers earn enough to meet their basic needs.",
  evidence: "MIT's 2024 estimates placed the living wage for one adult in Pennsylvania at $21.95 per hour, more than three times the federal minimum wage.",
  reasoning: "When wages fall below the cost of basic necessities, employment alone cannot guarantee economic security. A living wage helps workers afford housing, food, and healthcare, reducing financial insecurity and promoting economic dignity.",
  impacts: ["Housing", "Food", "Healthcare"],
  links: [
    { clear: false, note: "Needs explanation: your evidence covers one state, but your claim covers the whole country. Say why Pennsylvania is typical." },
    { clear: true, note: "Clear: you showed why a wage below the cost of living breaks economic security." },
  ],
  unfinished: "“…and businesses can afford to—” You started an affordability point and moved on before finishing it.",
  prompts: [
    "Pennsylvania isn't an outlier, because…",
    "Even if some businesses push back, a living wage is still required because…",
    "The most important impact is ___, because…",
  ],
};

export const DEMO_TIPS = [
  ["Argument", "Bridge Pennsylvania to the whole country.",
    "Your claim is national but your only number is from one state. Right after the MIT figure, add: “Pennsylvania isn't an outlier. MIT's calculator puts the living wage for a single adult above $7.25 in every state.” That turns the dashed link on your map solid."],
  ["Argument", "Finish the affordability point or cut it.",
    "The Negative's first answer will be that employers can't afford it and will cut jobs. Either finish your sentence with one warrant, such as “higher wages lower turnover, which cuts hiring and training costs,” or drop it. A half-made point hands them a free target."],
  ["Delivery", "Let the number land, then pause between tiers.",
    "You said “$21.95 per hour, more than three times” in about two seconds. Slow down on the figure, then take a full one-second pause before “When wages fall below…”. Your longest silence (2.6 seconds) came mid-claim after “moral obligation to”. Move it to the gap between evidence and reasoning."],
  ["Delivery", "Trade each “um” for a breath, and say every syllable.",
    "All three “um”s came right before your evidence. Take a silent breath there instead. You also clipped “necessities” to three syllables: say ne-CES-si-ties, and stress “living WAGE” each time it comes up."],
];

const average = (rows) => Math.round(rows.reduce((sum, [, v]) => sum + v, 0) / rows.length);

function ring(value) {
  const r = 52;
  const length = 2 * Math.PI * r;
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", "0 0 120 120");
  svg.setAttribute("aria-hidden", "true");
  svg.innerHTML = `<circle class="ring-track" cx="60" cy="60" r="${r}"/><circle class="ring-arc" cx="60" cy="60" r="${r}" stroke-dasharray="${length}" stroke-dashoffset="${length}"/>`;
  const number = h("span", { class: "ring-number" }, reduceMotion() ? String(value) : "0");
  const el = h("div", { class: "ring", role: "img", "aria-label": `${value}% delivery` }, svg,
    h("div", { class: "ring-label" }, h("span", { class: "ring-value" }, number, h("span", { class: "ring-unit" }, "%")), h("span", null, "Delivery")));
  const target = length * (1 - value / 100);
  const fill = svg.querySelector(".ring-arc");
  const play = () => {
    fill.style.strokeDashoffset = String(target);
    if (reduceMotion()) return;
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min(1, (now - start) / 1200);
      number.textContent = String(Math.round(value * (1 - Math.pow(1 - t, 3))));
      if (t < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };
  if (reduceMotion()) fill.style.strokeDashoffset = String(target);
  else new IntersectionObserver((entries, observer) => {
    if (!entries[0].isIntersecting) return;
    observer.disconnect();
    requestAnimationFrame(play);
  }, { threshold: 0.4 }).observe(el);
  return el;
}

function deliverySection() {
  return h("section", { class: "report-delivery" },
    ring(average(DEMO_DELIVERY)),
    h("div", { class: "report-meters" },
      DEMO_DELIVERY.map(([label, value, note]) => h("div", { class: "report-meter" },
        h("div", { class: "kv-line" }, h("span", null, label), h("span", { class: "strong" }, String(value))),
        h("div", { class: `bar ${value >= 80 ? "ok" : "low"}` }, h("div", { class: "bar-fill", style: { width: `${value}%` } })),
        h("span", { class: "subtext small" }, note)))));
}

const STAGES = [
  ["Detect", "Record a response and extract its main claims, supporting reasons, and unfinished thoughts."],
  ["Decode", "Construct a visual argument map showing which connections are clear and which need explanation."],
  ["Act", "Turn the map into optional speaking prompts, then let the student rerecord the argument and compare its structure."],
];

const node = (tier, label, text, cls, extra = null) => h("div", { class: `flow-node ${cls}` },
  h("span", { class: "flow-tier" }, `Tier ${tier}`),
  h("span", { class: "flow-label" }, label),
  h("p", null, text),
  extra);

const link = ({ clear, note }) => h("div", { class: `flow-link${clear ? " clear" : " gap"}` },
  h("span", { class: "flow-line", "aria-hidden": "true" }),
  h("span", { class: "flow-badge" }, icon(clear ? "check" : "alertCircle"), clear ? "Clear" : "Needs explanation"),
  h("span", { class: "flow-note" }, note));

export function argumentMap(map = DEMO_MAP) {
  return h("div", { class: "flow", role: "group", "aria-label": "Argument map" },
    node(1, "Claim", map.claim, "claim"),
    link(map.links[0]),
    node(2, "Evidence", map.evidence, "evidence"),
    link(map.links[1]),
    node(3, "Reasoning and impact", map.reasoning, "reasoning",
      h("div", { class: "flow-impacts" }, map.impacts.map((i) => h("span", null, i)))));
}

function mapSection(onRerecord) {
  return h("section", { class: "report-map" },
    h("div", { class: "report-head" },
      h("h3", null, "Your argument, mapped"),
      h("p", { class: "subtext" }, h("strong", null, "Distinctive feature: "), "A personalized visual representation of the student's own thinking.")),
    h("ol", { class: "stages" }, STAGES.map(([name, text], i) => h("li", null,
      h("span", { class: "stage-num" }, String(i + 1)),
      h("span", null, h("strong", null, `${name}: `), text)))),
    argumentMap(),
    h("div", { class: "flow-unfinished" }, icon("pencil"), h("span", null, h("strong", null, "Unfinished thought. "), DEMO_MAP.unfinished)),
    h("div", { class: "report-act" },
      h("span", { class: "flow-label" }, "Optional speaking prompts"),
      h("ul", { class: "prompt-list" }, DEMO_MAP.prompts.map((p) => h("li", null, p))),
      h("button", { type: "button", class: "button secondary compact", onClick: onRerecord }, icon("mic"), "Rerecord and compare")));
}

function tipsSection() {
  return h("section", { class: "report-tips" },
    h("h3", null, "Next steps"),
    h("ol", { class: "tip-list" }, DEMO_TIPS.map(([kind, title, body], i) => h("li", null,
      h("span", { class: "tip-num" }, String(i + 1)),
      h("div", null,
        h("span", { class: `tip-kind ${kind.toLowerCase()}` }, kind),
        h("strong", null, title),
        h("p", null, body))))));
}

export function recordingReport({ onRerecord } = {}) {
  return h("article", { class: "report", "aria-label": "Recording analysis" },
    h("div", { class: "report-title" }, icon("sparkle", "icon accent"), h("span", null, "Verbatim · Recording analysis")),
    deliverySection(),
    mapSection(onRerecord),
    tipsSection());
}

function detect(text) {
  const sentences = text.split(/(?<=[.!?])\s+/).filter(Boolean);
  const evidence = containsStatistic(text) || /\b(according to|study|estimate|report|data|MIT|percent|\$)/i.test(text);
  const reasoning = /\b(because|when|so|therefore|which means|helps|leads|reduc|promot|that's why|means)/i.test(text);
  const bridge = /\b(every state|all 50|nationwide|across the (country|nation|U\.?S)|outlier|typical|national)/i.test(text);
  return {
    claim: sentences.length > 0 && text.split(/\s+/).length >= 6,
    evidence,
    reasoning,
    links: [evidence && bridge, evidence && reasoning],
    unfinished: /(—|-{2}|\.\.\.|…)\s*$/.test(text.trim()) || /\b(and|but|so|to)\s*$/i.test(text.trim()),
  };
}

const TAKE_ONE = { claim: true, evidence: true, reasoning: true, links: [false, true], unfinished: true };

function compare(take2) {
  const rows = [
    ["Claim", TAKE_ONE.claim, take2.claim],
    ["Evidence", TAKE_ONE.evidence, take2.evidence],
    ["Reasoning and impact", TAKE_ONE.reasoning, take2.reasoning],
    ["Claim to evidence link", TAKE_ONE.links[0], take2.links[0]],
    ["Evidence to reasoning link", TAKE_ONE.links[1], take2.links[1]],
    ["No unfinished thoughts", !TAKE_ONE.unfinished, !take2.unfinished],
  ];
  const score = (i) => rows.filter((r) => r[i]).length;
  const mark = (ok) => h("span", { class: `cmp-mark ${ok ? "ok" : "miss"}` }, icon(ok ? "checkCircle" : "alertCircle"), ok ? "Clear" : "Missing");
  const delta = score(2) - score(1);
  return h("div", { class: "stack" },
    h("p", { class: "compare-verdict" }, delta > 0
      ? `Take 2 is stronger: ${delta} more part${delta === 1 ? "" : "s"} of your argument now connect.`
      : delta === 0 ? "Same structure as take 1. Try one of the speaking prompts to close the dashed link." : "Take 2 dropped a tier. Rebuild it from the claim outward."),
    h("div", { class: "compare", role: "table" },
      h("div", { class: "compare-row head", role: "row" }, h("span", null, ""), h("span", null, "Take 1"), h("span", null, "Take 2")),
      rows.map(([label, a, b]) => h("div", { class: "compare-row", role: "row" }, h("span", null, label), mark(a), mark(b)))));
}

export function rerecordDialog({ language }) {
  modal("Rerecord your argument", () => {
    const field = h("textarea", { class: "field", rows: "5", placeholder: "Tap the mic and give your argument again…", "aria-label": "Your second take" });
    const fit = autoGrow(field, 260);
    const result = h("div");
    const check = h("button", { type: "button", class: "button primary", disabled: true, onClick: () => replace(result, compare(detect(field.value))) }, "Compare structure");
    const sync = () => { fit(); check.disabled = !field.value.trim(); };
    field.addEventListener("input", sync);
    let mic = null;
    const dictate = dictation(field, language, (listening) => {
      if (listening !== undefined && mic) {
        mic.classList.toggle("listening", listening);
        mic.setAttribute("aria-pressed", listening ? "true" : "false");
      }
      sync();
    });
    if (dictate) mic = h("button", { type: "button", class: "icon-button mic", "aria-label": "Record", "aria-pressed": "false", onClick: () => dictate.toggle() }, icon("mic"));
    requestAnimationFrame(() => {
      field.focus();
      field.closest("dialog")?.addEventListener("close", () => dictate?.stop());
    });
    return h("div", { class: "stack" },
      subtext("Use the prompts from your map. When you're done, compare the structure of both takes."),
      h("div", { class: "prompt-chips" }, DEMO_MAP.prompts.map((p) => h("button", { type: "button", class: "chip", onClick: () => { field.value = `${field.value.trim()} ${p}`.trim(); sync(); field.focus(); } }, p))),
      h("div", { class: "composer-row rerecord-row" }, field, mic),
      check,
      result);
  });
}
