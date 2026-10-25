import {
  COMMITTEES, DIFFICULTIES, JUDGE_PRESETS, LANGUAGES, MODES, SIDES,
  congressSegment, effectiveKind, modeInfo, namesOn, opposite, questionsIn, sectionTitles,
} from "./public/js/data.js";
import { parseDecision, parseFeedback } from "./public/js/feedback.js";

const useGemini = () => !process.env.ANTHROPIC_API_KEY && Boolean(process.env.GEMINI_API_KEY);
export const model = () => (useGemini() ? process.env.GEMINI_MODEL || "gemini-3.6-flash" : process.env.CLAUDE_MODEL || "claude-sonnet-5");
const GEMINI_FALLBACK = "gemini-flash-lite-latest";
const endpoint = () => `${(process.env.ANTHROPIC_BASE_URL || "https://api.anthropic.com").replace(/\/$/, "")}/v1/messages`;
const API_VERSION = "2023-06-01";

export const hasKey = () => Boolean(process.env.ANTHROPIC_API_KEY || process.env.GEMINI_API_KEY);

export class ClaudeError extends Error {
  constructor(message, status = 502) {
    super(message);
    this.status = status;
  }
}

const MODE_IDS = Object.values(MODES).map((m) => m.id);
const pick = (value, allowed, fallback) => (allowed.includes(value) ? value : fallback);
const clip = (value, max) => String(value ?? "").slice(0, max);

export function cleanConfig(c = {}) {
  const committee = COMMITTEES.find((x) => x.fullName === c.committee);
  return {
    kind: c.kind === "congress" ? "congress" : "debate",
    topic: clip(c.topic, 600).trim(),
    language: pick(c.language, LANGUAGES.map((l) => l.id), "English"),
    difficulty: pick(c.difficulty, DIFFICULTIES.map((d) => d.id), "Medium"),
    mode: pick(c.mode, MODE_IDS, "Debate"),
    userSide: pick(c.userSide, SIDES, "Affirmative"),
    participants: (Array.isArray(c.participants) ? c.participants : []).slice(0, 4).map((p) => ({
      name: clip(p?.name, 40).trim() || "Debater",
      side: pick(p?.side, SIDES, "Affirmative"),
      role: clip(p?.role, 40),
      isUser: Boolean(p?.isUser),
    })),
    judgePreset: pick(c.judgePreset, Object.keys(JUDGE_PRESETS), "Novice"),
    committee: committee ? committee.fullName : "",
    billText: clip(c.billText, 6000),
    lowPressure: Boolean(c.lowPressure),
    plainLanguage: Boolean(c.plainLanguage),
  };
}

export function cleanHistory(history) {
  return (Array.isArray(history) ? history : []).slice(-200).map((m) => ({
    role: m?.role === "assistant" ? "assistant" : "user",
    text: clip(m?.text, 8000),
    speaker: m?.speaker ? clip(m.speaker, 60) : null,
    kind: ["speech", "crossfireQuestion", "crossfireAnswer", "inquiry", "ruling", "amendment"].includes(m?.kind) ? m.kind : null,
  }));
}

const userIsAuthor = (c) => c.userSide === "Affirmative";

const LOW_PRESSURE_NOTE = "\n\nThe student has asked for a lower-pressure round. Keep every rule above, but stay calm and courteous, never mock or belittle, keep each response under 120 words, and take on one or two points at a time.";
const PLAIN_LANGUAGE_NOTE = "\n\nWrite in plain language: short sentences, everyday words, and define any debate jargon you use the first time it appears.";

function debateSystemPrompt(c) {
  let prompt = `You are a skilled, competitive debate opponent arguing the opposing side of the resolution: ${c.topic}. Your goal is to win the argument, not to make the user feel good. Challenge weak points directly. Do not concede unless the user's argument is genuinely airtight. Do not use softening phrases like 'great point, but...' — go straight to your rebuttal. Do not praise the user during the debate. Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate — prefer logical reasoning and widely-known general knowledge over invented figures. Stay strictly on the topic: ${c.topic}. Respond in ${c.language}. Match your argument complexity to difficulty level: ${c.difficulty}.`;
  if (c.lowPressure) prompt += LOW_PRESSURE_NOTE;
  return prompt;
}

function coachSystemPrompt(c) {
  let prompt = `You are a debate coach reviewing a student's argument. Give specific, structured, constructive feedback — not encouragement for its own sake. Do not praise the user unless the praise is tied to a specific, identifiable strength you can quote from their text. Do not soften criticism with excessive hedging. Structure your response into exactly these four labeled sections: Strongest argument (with a quote), Weakest argument (with a quote), Missed rebuttal opportunity, Concrete suggestion for next time. Respond in ${c.language}.`;
  if (c.plainLanguage) prompt += PLAIN_LANGUAGE_NOTE;
  return prompt;
}

function teamSystemPrompt(c) {
  const opposing = opposite(c.userSide);
  let prompt = `You are the entire opposing team in a Public Forum style debate on the resolution: ${c.topic}. The human team of two argues the ${c.userSide.toLowerCase()}; you argue the ${opposing.toLowerCase()} and you play both of your team's speakers. Begin every speech with a line naming who is speaking: "First Speaker:" builds and extends your team's case and constructive arguments; "Second Speaker:" rebuts the human team's most recent arguments point by point. Your goal is to win the round. Challenge weak points directly, do not praise the human team, and do not concede unless an argument is genuinely airtight. Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate — prefer logical reasoning and widely known general knowledge. End every speech with a section headed "Crossfire:" containing exactly two pointed rhetorical questions the human team must answer, each exposing a gap or assumption in their case. Keep each speech under 220 words. Respond in ${c.language}. Match your complexity to difficulty level: ${c.difficulty}.`;
  if (c.lowPressure) prompt += LOW_PRESSURE_NOTE;
  return prompt;
}

const statCheckSystemPrompt = (language) =>
  `You are a careful fact-checker for a student debater. The student has just cited one or more numbers, statistics, or dollar figures in a practice speech. For each figure, give a one-line verdict — "Likely accurate", "Questionable", or "Can't verify" — followed by a short reason and the best source to confirm it (a specific agency, dataset, or report). Be honest about the limits of your knowledge and its cutoff date; never invent a corrected number unless you are highly confident. Keep the whole response under 120 words. Respond in ${language}.`;

const billBlock = (c, label) => (c.billText ? `\n\n${label}\n"""\n${c.billText.slice(0, 6000)}\n"""` : "");

function congressSpeechSystemPrompt(c, segment) {
  const role = !userIsAuthor(c)
    ? "You are the sponsor and author of the legislation. You wrote this bill, you speak for it throughout, and you defend it from every attack the student makes."
    : "You are a member speaking in opposition to the legislation. The student is its sponsor; you speak only against the bill.";
  const opening = segment.title === "Authorship speech"
    ? " This is your authorship speech: introduce the bill, explain the problem it solves, walk the chamber through what it actually does, and give the two strongest reasons to pass it."
    : " Directly refute the student's most recent arguments before advancing your own.";
  let prompt = `You are a member of a model congress serving on the ${c.committee}, debating the legislation: ${c.topic}. ${role}${billBlock(c, "The text of the legislation under debate:")}

You are now delivering your ${segment.title.toLowerCase()}, a ${segment.clock} speech in ${segment.stance === "Pro" ? "support of" : "opposition to"} the bill. Write roughly ${segment.wordBudget} words — the amount a speaker covers in ${segment.clock} at a normal speaking pace.${opening} End with exactly one pointed cross-examination question for the student. Maintain parliamentary decorum at all times; address the student as "the representative" or "the senator". Do not cite specific statistics, studies, or numbers unless you are highly confident they are accurate; prefer reasoning and widely known facts, and write "(verify)" after any figure you do use. Respond in ${c.language}. Match your rigor to difficulty level: ${c.difficulty}.`;
  if (c.lowPressure) prompt += LOW_PRESSURE_NOTE;
  return prompt;
}

function congressAmendmentSystemPrompt(c) {
  const role = userIsAuthor(c)
    ? "You have been speaking against the bill; the student is its sponsor."
    : "You are the sponsor and author of the bill; the student has been speaking against it.";
  let prompt = `You are a member of a model congress on the ${c.committee} debating the legislation: ${c.topic}. ${role}${billBlock(c, "The text of the legislation:")}

The student has yielded the floor. You may move an amendment, but only if one is genuinely warranted by how the debate went — a specific weakness a speaker actually exposed, or a gap in the bill's text.

If an amendment is warranted, structure your turn with these labels, each on its own line: "Motion:" — the formal motion, phrased as "I move to amend the bill by…" naming the specific clause or section and the exact change. "Rationale:" — two or three sentences on why it is necessary, tied to what was actually argued. "Question to the sponsor:" — one pointed question the student must answer.

If no amendment is warranted, do not invent one. Reply with a single line beginning "No motion:" followed by one sentence explaining why the bill should stand or fall as written. Keep the whole turn under 200 words. Do not invent statistics; write "(verify)" after any figure. Respond in ${c.language}.`;
  if (c.lowPressure) prompt += LOW_PRESSURE_NOTE;
  return prompt;
}

const parliamentarianInquirySystemPrompt = (c) =>
  `You are the presiding officer and parliamentarian of a model congress session on the ${c.committee}, debating: ${c.topic}. You are a neutral third party: you are not debating, you do not take a side, and you never argue for or against the bill. A member has risen to a point of inquiry and asked you to look something up or clarify a point of procedure.

Answer in two labeled parts. "Ruling:" — a direct answer in two or three sentences. "Where to verify:" — the specific agency, dataset, or report the member should check, named precisely.

Accuracy matters more than completeness. You have no live internet access and your knowledge has a cutoff date, so: state a figure only if you are highly confident, give it as an approximate value with its year and end it with "(verify)". If you are not confident, say plainly that you cannot confirm it from the chair and name exactly where the member should look. Never invent a number, a citation, or a rule. If the inquiry is procedural rather than factual, rule on it using standard parliamentary procedure. Respond in ${c.language}.`;

const statLookupSystemPrompt = (language) =>
  `You are a research assistant helping a student debater find a statistic they can use at the podium. Answer in three labeled parts, each on its own line. "Figure:" — the number itself, given as an approximate value with the year it comes from, ending with "(verify)". "Context:" — one or two sentences on what the number means and how a debater should and should not use it. "Source:" — the exact agency, dataset, or report that publishes it, named precisely enough to search for.

Accuracy matters more than completeness. You have no live internet access and your knowledge has a cutoff date, so a figure that changes often — prices, counts that grow monthly, anything "right now" — should be given as the most recent value you are confident in, clearly labeled with its year, plus a warning that it has likely changed. If you are not confident of any figure, say so plainly under "Figure:" and put all your effort into naming exactly where the student can look it up. Never invent a number or a citation. Respond in ${language}.`;

function parliamentarianSystemPrompt(c) {
  let prompt = `You are the parliamentarian and scoring judge for a Congressional Debate round in the ${c.committee} on the legislation: ${c.topic}. Review the student's speeches and answers using standard Congressional Debate criteria: argumentation and clash, quality of evidence and reasoning, organization and clarity, responsiveness in questioning, and decorum. Give specific, structured, constructive feedback — not encouragement for its own sake. Do not praise the student unless the praise is tied to a specific, identifiable strength you can quote from their text. Do not soften criticism with excessive hedging. Structure your response into exactly these four labeled sections: Strongest argument (with a quote), Weakest argument (with a quote), Missed opportunity in refutation or questioning, Concrete suggestion for next time. Respond in ${c.language}.`;
  if (c.plainLanguage) prompt += PLAIN_LANGUAGE_NOTE;
  return prompt;
}

function judgeSystemPrompt(c, affirmative, negative) {
  const preset = JUDGE_PRESETS[c.judgePreset];
  let prompt = `You are the judge of a debate on the resolution: ${c.topic}. ${affirmative} argued the affirmative and ${negative} argued the negative. Judge paradigm and instructions: ${preset.instructions} Decide the round using only what was said in the transcript. Be specific: quote the debaters' own words when explaining what decided the round. Respond in ${c.language}.`;
  if (preset.sampleRFD) {
    prompt += `\n\nHere is a sample reason for decision written by a real judge in the style expected of you. Match its voice, its level of technical vocabulary, its specificity about which arguments were extended, dropped, or under-warranted, and its willingness to say plainly what did and did not persuade you. Do not copy its content, topic, or debaters — only its style and depth:\n"""\n${preset.sampleRFD}\n"""`;
  }
  if (c.plainLanguage) prompt += PLAIN_LANGUAGE_NOTE;
  return prompt;
}

const crossfireSystemPrompt = (c) =>
  `You are the opposing team in a Public Forum style debate on the resolution: ${c.topic}, arguing the ${opposite(c.userSide).toLowerCase()}. It is now crossfire. Ask the opposing team exactly three questions about the resolution and about the case they just presented. Each question must be a genuine cross-examination question that exposes a gap, an unwarranted assumption, or an unsupported number in their case — the kind a debater must answer on the spot. Number them 1., 2., and 3., one per line, with no preamble, no commentary, and nothing after the third question. Keep each question under 40 words. Respond in ${c.language}. Match your rigor to difficulty level: ${c.difficulty}.`;

function formatInstruction(c) {
  const labels = sectionTitles(c.kind).map((t) => `"${t}:"`).join(", ");
  return `Use exactly these four section labels, each on its own line and kept in English: ${labels}. Write the content under each label in ${c.language}. Do not add any other headings, sections, or preamble.`;
}

function apiMessages(history) {
  const result = [];
  for (const message of history) {
    const text = message.text.trim();
    if (!text) continue;
    const last = result[result.length - 1];
    if (last && last.role === message.role) last.content += "\n\n" + text;
    else result.push({ role: message.role, content: text });
  }
  if (result[0]?.role === "assistant") result.shift();
  return result;
}

async function sendGemini(system, messages, maxTokens, name = model()) {
  let res;
  try {
    res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(name)}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": process.env.GEMINI_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: messages.map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] })),
        generationConfig: { maxOutputTokens: maxTokens * 4 },
      }),
      signal: AbortSignal.timeout(90_000),
    });
  } catch (e) {
    throw new ClaudeError(`Network error: ${e.message}`);
  }
  const json = await res.json().catch(() => null);
  if (res.status === 503 && name !== GEMINI_FALLBACK) return sendGemini(system, messages, maxTokens, GEMINI_FALLBACK);
  if (res.status === 429) throw new ClaudeError("Gemini's free tier limit was reached. Wait a minute and try again.", 429);
  if (!res.ok) throw new ClaudeError(`API error (${res.status}): ${json?.error?.message || `HTTP ${res.status}`}`);
  const text = (json?.candidates?.[0]?.content?.parts || []).filter((p) => p.text && !p.thought).map((p) => p.text).join("").trim();
  if (!text) throw new ClaudeError("The API returned an unexpected response.");
  return text;
}

async function send(system, messages, maxTokens) {
  if (!messages.length) throw new ClaudeError("There's nothing to respond to yet.", 400);
  if (useGemini()) return sendGemini(system, messages, maxTokens);
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new ClaudeError("The server has no AI key. Set ANTHROPIC_API_KEY or GEMINI_API_KEY in server/.env and restart it.", 503);

  let res;
  try {
    res = await fetch(endpoint(), {
      method: "POST",
      headers: { "x-api-key": key, "anthropic-version": API_VERSION, "content-type": "application/json" },
      body: JSON.stringify({ model: model(), max_tokens: maxTokens, system, messages }),
      signal: AbortSignal.timeout(90_000),
    });
  } catch (e) {
    throw new ClaudeError(`Network error: ${e.message}`);
  }
  const json = await res.json().catch(() => null);
  if (!res.ok) throw new ClaudeError(`API error (${res.status}): ${json?.error?.message || `HTTP ${res.status}`}`);
  const text = (json?.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n").trim();
  if (!text) throw new ClaudeError("The API returned an unexpected response.");
  return text;
}

export async function liveTurn(c, history) {
  switch (c.mode) {
    case "Debate":
      return send(debateSystemPrompt(c), apiMessages(history), 1024);
    case "Coach":
      return coachTurnFeedback(c, history);
    case "Congress": {
      const index = history.filter((m) => ["speech", "amendment"].includes(effectiveKind(m))).length;
      const segment = congressSegment(index);
      if (!segment) return send(congressAmendmentSystemPrompt(c), apiMessages(history), 700);
      const messages = apiMessages(history);
      if (!messages.length) messages.push({ role: "user", content: "The chair recognizes the sponsor of the bill for the authorship speech." });
      return send(congressSpeechSystemPrompt(c, segment), messages, segment.seconds >= 240 ? 1400 : 800);
    }
    case "Team vs AI": {
      const messages = apiMessages(history);
      const aiTurns = history.filter((m) => m.role === "assistant").length;
      const role = aiTurns % 2 === 0 ? "First Speaker" : "Second Speaker";
      const last = messages[messages.length - 1];
      if (last?.role === "user") last.content += `\n\n(Respond now as your ${role}.)`;
      return send(teamSystemPrompt(c), messages, 900);
    }
    default:
      throw new ClaudeError("That mode has no AI turn.", 400);
  }
}

export async function crossfireQuestions(c, history) {
  let prompt = `The human team argued the ${c.userSide.toLowerCase()}. Transcript so far:\n\n`;
  for (const m of history) prompt += `${m.speaker || (m.role === "user" ? "Opposing team" : "You")}: ${m.text}\n\n`;
  prompt += "Ask your three crossfire questions now.";
  const raw = await send(crossfireSystemPrompt(c), [{ role: "user", content: prompt }], 500);
  const questions = questionsIn(raw);
  if (questions.length !== 3) throw new ClaudeError("The API returned an unexpected response.");
  return questions;
}

export function checkStatistics(text, topic, language) {
  const prompt = `Resolution or bill under debate: ${topic}\n\nThe student's speech:\n"""\n${text}\n"""\n\nCheck every number, percentage, or dollar figure in it.`;
  return send(statCheckSystemPrompt(language), [{ role: "user", content: prompt }], 400);
}

async function coachTurnFeedback(c, history) {
  const studentTurns = history.filter((m) => m.role === "user").map((m) => m.text);
  const latest = studentTurns[studentTurns.length - 1];
  if (!latest) throw new ClaudeError("Give at least one argument first.", 400);
  const earlier = studentTurns.slice(0, -1);

  let prompt = `Resolution: "${c.topic}"\nThe student is arguing in favor of the resolution. Difficulty level: ${c.difficulty}.\n\n`;
  if (earlier.length) {
    prompt += "Earlier arguments from the student in this session (context only, do not review these):\n";
    earlier.forEach((t, i) => { prompt += `${i + 1}. ${t}\n`; });
    prompt += "\n";
  }
  prompt += `Latest argument to review:\n"""\n${latest}\n"""\n\nReview only the latest argument. Quote the student's own words.\n\n`;
  prompt += formatInstruction(c);
  return send(coachSystemPrompt(c), [{ role: "user", content: prompt }], 1024);
}

export async function postSessionFeedback(c, transcript) {
  let prompt = c.kind === "congress"
    ? `Committee: ${c.committee}\nLegislation: ${c.topic}\nThe student spoke in ${userIsAuthor(c) ? "affirmation of the bill as its sponsor, giving the authorship speech" : "negation of the bill, answering an AI sponsor who authored and defended it"}. Difficulty: ${c.difficulty}.`
    : `Resolution: "${c.topic}"\nMode: ${c.mode}. Difficulty: ${c.difficulty}.\nThe student argued in favor of the resolution.`;
  if (c.mode === "Team vs AI") {
    prompt += `\nThis was a two-person team round: ${namesOn(c, c.userSide)} argued the ${c.userSide.toLowerCase()} together against an AI opposing team. The round included a crossfire in which the opposing team asked three questions and the human team answered them live. Review the human team's speeches and their crossfire answers, noting specifically how directly and completely each question was answered.`;
  }
  prompt += "\nHere is the full transcript:\n\n";
  for (const m of transcript) {
    let speaker;
    switch (effectiveKind(m)) {
      case "inquiry": speaker = "Student (point of inquiry)"; break;
      case "ruling": speaker = "Parliamentarian (ruling, not part of the student's speeches)"; break;
      case "amendment": speaker = m.role === "user" ? "Student (on the amendment)" : "Opposing member (motion to amend)"; break;
      default: speaker = m.role === "user" ? (c.mode === "Team vs AI" ? m.speaker || "Student" : "Student") : modeInfo(c.mode).assistantLabel;
    }
    prompt += `${speaker}: ${m.text}\n\n`;
  }
  prompt += "Review the student's performance across the whole session. Quote their own words when identifying the strongest and weakest parts.\n\n";
  prompt += formatInstruction(c);

  const system = c.kind === "congress" ? parliamentarianSystemPrompt(c) : coachSystemPrompt(c);
  return parseFeedback(await send(system, [{ role: "user", content: prompt }], 1500));
}

export async function judgeRound(c, transcript) {
  const affirmative = namesOn(c, "Affirmative");
  const negative = namesOn(c, "Negative");
  let prompt = `Resolution: "${c.topic}"\nAffirmative: ${affirmative}\nNegative: ${negative}\n\nTranscript, in speaking order:\n\n`;
  for (const m of transcript) prompt += `${m.speaker || "Speaker"}: ${m.text}\n\n`;
  prompt += `Judge the round. Use exactly these four section labels, each on its own line and kept in English: "Decision:", "Reason for decision:", "Feedback for the Affirmative:", "Feedback for the Negative:". Under "Decision:" write only the winning side and the name(s) of who argued it. Write the content in ${c.language}. Do not add any other headings, sections, or preamble.`;
  const raw = await send(judgeSystemPrompt(c, affirmative, negative), [{ role: "user", content: prompt }], 1800);
  return parseDecision(raw, affirmative, negative);
}

export function pointOfInquiry(c, question, history) {
  let prompt = "Debate so far:\n\n";
  for (const m of history.slice(-6)) prompt += `${m.speaker || (m.role === "user" ? "The member" : "Opposing member")}: ${m.text}\n\n`;
  prompt += `The member rises to a point of inquiry:\n"""\n${question}\n"""\n\nRule on it.`;
  return send(parliamentarianInquirySystemPrompt(c), [{ role: "user", content: prompt }], 600);
}

export function lookUpStatistic(question, committeeName, language) {
  const committee = COMMITTEES.find((x) => x.fullName === committeeName || x.name === committeeName);
  if (!committee) throw new ClaudeError("Unknown committee.", 400);
  const prompt = `The student is debating in the ${committee.fullName}, whose jurisdiction is: ${committee.jurisdiction}
The sources this committee relies on are: ${committee.sources.map((s) => s.title).join(", ")}.

Their question: "${question}"`;
  return send(statLookupSystemPrompt(language), [{ role: "user", content: prompt }], 700);
}
