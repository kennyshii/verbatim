export const FILLER_PENALTY = 5;

const ALWAYS_FILLERS = [
  "um", "umm", "uh", "uhh", "er", "erm", "ah", "hmm", "mhm",
  "you know", "i mean", "basically", "literally", "actually", "honestly", "obviously",
  "kind of", "sort of", "kinda", "sorta", "okay so", "so yeah", "or whatever",
  "stuff like that", "things like that", "you know what i mean", "at the end of the day",
];

const CONTEXTUAL_PATTERNS = [
  ["like", String.raw`(?:,\s*like\b|\blike,)`],
  ["so", String.raw`(?:^|[.!?,]\s*)so,`],
  ["well", String.raw`(?:^|[.!?,]\s*)well,`],
  ["right?", String.raw`\bright\?`],
];

const HEDGES = ["i think", "i guess", "maybe", "perhaps", "probably", "i feel like", "not sure", "might be", "i suppose", "in my opinion", "kind of", "sort of", "a little bit", "i'm not an expert"];
const HOSTILE = ["stupid", "dumb", "idiot", "idiotic", "shut up", "ridiculous", "nonsense", "moron", "pathetic", "you people", "liar", "garbage"];
const ABSOLUTES = ["always", "never", "everyone", "nobody", "no one", "everybody", "obviously", "clearly", "undeniably", "without a doubt"];

const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const plural = (n, word, suffix = "s") => `${n} ${word}${n === 1 ? "" : suffix}`;

function matches(pattern, text) {
  return (text.match(new RegExp(pattern, "gm")) || []).length;
}

const wordPattern = (phrase) => String.raw`\b` + escape(phrase) + String.raw`\b`;

export const EMPTY = {
  wordCount: 0, fillerCount: 0, hits: [], fillerScore: 100,
  smoothness: 100, smoothnessNotes: [], tone: 100, toneLabel: "—", toneNotes: [],
};

export function overall(m) {
  if (!m.wordCount) return 100;
  return Math.round(m.fillerScore * 0.4 + m.smoothness * 0.3 + m.tone * 0.3);
}

export function fillerSummary(m) {
  if (!m.wordCount) return "Nothing to measure yet.";
  if (!m.fillerCount) return `${m.wordCount} words, no filler words. Full marks.`;
  const list = m.hits.map((h) => `${h.phrase} ×${h.count}`).join(", ");
  return `${m.wordCount} words · ${plural(m.fillerCount, "filler")} (−${FILLER_PENALTY} each): ${list}`;
}

export function smoothnessSummary(m) {
  if (!m.wordCount) return "Nothing to measure yet.";
  return m.smoothnessNotes.length ? m.smoothnessNotes.join(" · ") : "Sentences flow: no run-ons, fragments, or restarts.";
}

export function toneSummary(m) {
  if (!m.wordCount) return "Nothing to measure yet.";
  return m.toneNotes.length ? `${m.toneLabel}: ${m.toneNotes.join(" · ")}` : `${m.toneLabel}.`;
}

export function analyze(text) {
  const original = String(text || "");
  const normalized = original.replace(/’/g, "'").toLowerCase();
  const words = normalized.split(/\s+/).filter(Boolean);
  if (!words.length) return { ...EMPTY };

  const counts = new Map();
  for (const phrase of ALWAYS_FILLERS) {
    const n = matches(wordPattern(phrase), normalized);
    if (n) counts.set(phrase, (counts.get(phrase) || 0) + n);
  }
  for (const [label, pattern] of CONTEXTUAL_PATTERNS) {
    const n = matches(pattern, normalized);
    if (n) counts.set(label, (counts.get(label) || 0) + n);
  }
  const hits = [...counts].map(([phrase, count]) => ({ phrase, count }))
    .sort((a, b) => (a.count !== b.count ? b.count - a.count : a.phrase < b.phrase ? -1 : 1));
  const fillerCount = hits.reduce((sum, h) => sum + h.count, 0);
  const fillerScore = Math.max(0, 100 - fillerCount * FILLER_PENALTY);

  const [smooth, smoothNotes] = smoothness(normalized, words);
  const [toneScore, toneLabel, toneNotes] = tone(original, normalized);

  return {
    wordCount: words.length, fillerCount, hits, fillerScore,
    smoothness: smooth, smoothnessNotes: smoothNotes,
    tone: toneScore, toneLabel, toneNotes,
  };
}

export const analyzeTurns = (turns) => analyze(turns.join("\n"));

function smoothness(normalized, words) {
  let score = 100;
  const notes = [];

  const sentences = normalized.split(/[.!?\n]/).map((s) => s.trim()).filter(Boolean);
  const lengths = sentences.map((s) => s.split(" ").filter(Boolean).length);

  const runOns = lengths.filter((n) => n > 35).length;
  if (runOns) { score -= runOns * 6; notes.push(`${plural(runOns, "run-on sentence")} over 35 words`); }

  const fragments = sentences.filter((_, i) => i > 0 && lengths[i] < 3).length;
  if (fragments) { score -= fragments * 3; notes.push(`${plural(fragments, "fragment")} under 3 words`); }

  let stumbles = 0;
  for (let i = 1; i < words.length; i++) {
    if (words[i] === words[i - 1] && words[i].length > 1 && /\p{L}/u.test(words[i])) stumbles++;
  }
  if (stumbles) { score -= stumbles * 5; notes.push(`${plural(stumbles, "repeated word")} ("the the")`); }

  const restarts = matches(String.raw`(\.\.\.|—|--|\s-\s)`, normalized);
  if (restarts) { score -= restarts * 3; notes.push(`${plural(restarts, "restart")} or trailing off`); }

  const commaHeavy = sentences.filter((s) => (s.match(/,/g) || []).length >= 5).length;
  if (commaHeavy) { score -= commaHeavy * 3; notes.push(`${plural(commaHeavy, "sentence")} with 5+ commas`); }

  if (lengths.length) {
    const mean = lengths.reduce((a, b) => a + b, 0) / lengths.length;
    if (mean > 30) { score -= 6; notes.push(`average sentence is ${Math.floor(mean)} words — break them up`); }
    if (sentences.length === 1 && words.length > 25) { score -= 6; notes.push("one long breath with no full stops"); }
  }

  return [Math.max(0, Math.min(100, score)), notes];
}

function tone(original, normalized) {
  let score = 100;
  const notes = [];

  const count = (list) => list.reduce((sum, w) => sum + matches(wordPattern(w), normalized), 0);

  const hedgeCount = count(HEDGES);
  if (hedgeCount) { score -= hedgeCount * 4; notes.push(`${plural(hedgeCount, "hedge")} ("I think", "maybe")`); }

  const hostileCount = count(HOSTILE);
  if (hostileCount) { score -= hostileCount * 12; notes.push(`${plural(hostileCount, "hostile word")}`); }

  const shouting = original.split(/\s+/).filter((w) => w.length >= 3 && /\p{Lu}/u.test(w) && !/\p{Ll}/u.test(w)).length;
  if (shouting) { score -= shouting * 3; notes.push(`${plural(shouting, "all-caps word")}`); }

  const exclaims = matches(String.raw`!{2,}|\?{2,}`, original);
  if (exclaims) { score -= exclaims * 3; notes.push("stacked punctuation (!! or ??)"); }

  const absoluteCount = count(ABSOLUTES);
  if (absoluteCount > 2) { score -= Math.min(12, (absoluteCount - 2) * 3); notes.push(`${absoluteCount} absolutes ("always", "everyone") — easy to refute`); }

  let label;
  if (hostileCount > 0 || shouting >= 3) label = "Overheated";
  else if (hedgeCount >= 3) label = "Hedging";
  else if (score >= 85) label = "Confident and measured";
  else label = "Uneven";

  return [Math.max(0, Math.min(100, score)), label, notes];
}

export function containsStatistic(text) {
  return matches(String.raw`(\d[\d,.]*\s*(%|percent|million|billion|trillion|thousand)|\$\s*\d|\d+\s*(out of|in every|per)\s+\d+|\b\d+x\b)`, String(text).toLowerCase()) > 0;
}
