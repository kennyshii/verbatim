export const NOT_PROVIDED = "Not provided.";

const DECORATION = new Set([..."#*_-•>0123456789.) \t"]);

function matchLabel(line, labels) {
  let i = 0;
  while (i < line.length && DECORATION.has(line[i])) i++;
  const stripped = line.slice(i).trim();
  const lower = stripped.toLowerCase();

  for (let index = 0; index < labels.length; index++) {
    for (const label of labels[index]) {
      if (!lower.startsWith(label)) continue;
      let rest = stripped.slice(label.length).replace(/^[*_\s]+/, "");
      if (rest.startsWith("(")) {
        const close = rest.indexOf(")");
        if (close >= 0) rest = rest.slice(close + 1);
      }
      rest = rest.replace(/^[:*_\-–— \t]+|[:*_ \t]+$/g, "");
      return [index, rest];
    }
  }
  return null;
}

export function sections(raw, labels) {
  const buckets = new Map();
  let current = null;

  for (const line of String(raw).split(/\r?\n/)) {
    const match = matchLabel(line, labels);
    if (match) {
      const [index, remainder] = match;
      current = index;
      if (remainder) buckets.set(index, [...(buckets.get(index) || []), remainder]);
    } else if (current !== null) {
      buckets.set(current, [...(buckets.get(current) || []), line]);
    }
  }
  if (!buckets.size) return null;

  return labels.map((_, index) => {
    const joined = (buckets.get(index) || []).join("\n").trim();
    return joined || NOT_PROVIDED;
  });
}

export function parseFeedback(raw) {
  const labels = [
    ["strongest argument", "strongest answer"],
    ["weakest argument", "weakest answer"],
    ["missed rebuttal opportunity", "missed rebuttal", "missed opportunity in refutation or questioning", "missed opportunity"],
    ["concrete suggestion for next time", "concrete suggestion", "suggestion for next time", "suggestion"],
  ];
  const parts = sections(raw, labels);
  if (!parts) {
    const fallback = String(raw).trim();
    return { strongestArgument: fallback || NOT_PROVIDED, weakestArgument: NOT_PROVIDED, missedRebuttal: NOT_PROVIDED, suggestion: NOT_PROVIDED };
  }
  return { strongestArgument: parts[0], weakestArgument: parts[1], missedRebuttal: parts[2], suggestion: parts[3] };
}

export function parseDecision(raw, affirmative, negative) {
  const labels = [
    ["decision"],
    ["reason for decision", "rfd"],
    ["feedback for the affirmative", "feedback for affirmative", "affirmative feedback", `feedback for ${affirmative.toLowerCase()}`],
    ["feedback for the negative", "feedback for negative", "negative feedback", `feedback for ${negative.toLowerCase()}`],
  ];
  const parts = sections(raw, labels);
  if (!parts) {
    const fallback = String(raw).trim();
    return { winner: NOT_PROVIDED, reasonForDecision: fallback || NOT_PROVIDED, affirmativeFeedback: NOT_PROVIDED, negativeFeedback: NOT_PROVIDED };
  }
  return { winner: parts[0], reasonForDecision: parts[1], affirmativeFeedback: parts[2], negativeFeedback: parts[3] };
}

const TAG_RULES = [
  ["Rebuttals", ["rebut", "refut", "counter", "respond to", "réfut", "réplique", "contraargument"]],
  ["Evidence use", ["evidence", "example", "data", "statistic", "source", "cite", "support your", "evidencia", "ejemplo", "preuve", "exemple"]],
  ["Structure", ["structure", "organiz", "organis", "outline", "signpost", "estructura", "organiza"]],
  ["Clarity", ["clarity", "clear", "vague", "unclear", "precise", "specific", "claridad", "claro", "clarté", "clair", "vago", "vague"]],
  ["Logical reasoning", ["logic", "assumption", "fallacy", "reasoning", "warrant", "premise", "lógica", "logique", "suposición", "supposition", "razonamiento", "raisonnement"]],
  ["Handling concessions", ["concede", "concession", "acknowledge", "grant that", "conced", "reconoc", "reconna"]],
  ["Impact and stakes", ["impact", "consequence", "why it matters", "stakes", "impacto", "consecuencia", "conséquence", "enjeu"]],
];

export function improvementText(feedback) {
  if (!feedback) return "";
  if (feedback.type === "judge") return `${feedback.decision.affirmativeFeedback} ${feedback.decision.negativeFeedback}`;
  return `${feedback.feedback.weakestArgument} ${feedback.feedback.suggestion}`;
}

export function recurringTags(sessions, minCount = 2) {
  const counts = new Map();
  for (const session of sessions) {
    if (!session.feedback) continue;
    const text = improvementText(session.feedback).toLowerCase();
    for (const [tag, keywords] of TAG_RULES) {
      if (keywords.some((k) => text.includes(k))) counts.set(tag, (counts.get(tag) || 0) + 1);
    }
  }
  return [...counts]
    .filter(([, count]) => count >= minCount)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => (a.count !== b.count ? b.count - a.count : a.name < b.name ? -1 : 1));
}
