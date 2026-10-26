import {
  FLOOR_SPEECH, congressIsOpenFloor, congressSegment, effectiveKind, isJudged, isMultiplayer, modeInfo, questionsIn, teamStep,
} from "../data.js";
import * as api from "../api.js";
import { reveal } from "../motion.js";
import { analyze, containsStatistic } from "../metrics.js";
import { dictation, speak, stop as stopSpeaking } from "../speech.js";
import * as store from "../store.js";
import { autoGrow, confirmDialog, h, icon, meterBar, modal, pageHeader, replace, topicBox } from "../ui.js";
import { messageBubble } from "./bubble.js";
import { analysisPage, rerecordDialog } from "./report.js";

const TITLES = { Debate: "Debate", Coach: "Coach session", "1v1": "1v1", "2v2": "2v2", "Team vs AI": "Team vs AI", Congress: "Congress round" };

let nextId = 1;
const newId = () => `m${Date.now().toString(36)}${(nextId++).toString(36)}`;

export function crossfireLabel(cf) {
  return [h("div", { class: "bubble-tag" }, icon("question"), `Crossfire question ${cf.index} of ${cf.total}`), h("div", null, cf.text)];
}

export function composer({ language, placeholder, onSend, onInput }) {
  const prefs = store.prefs();
  const textarea = h("textarea", { class: "field composer-input", rows: "1", placeholder, "aria-label": "Your speech" });
  const fit = autoGrow(textarea);
  const meter = h("div", { class: "composer-meter" });
  const send = h("button", { type: "button", class: "button primary compact", onClick: () => onSend() }, "Send");
  let mic = null;
  let recorded = false;

  const refresh = () => {
    fit();
    replace(meter, prefs.showFillerMeter && textarea.value ? meterBar(analyze(textarea.value), { compact: true }) : null);
    onInput();
  };

  const listeningCard = h("div", { class: "listening-card", role: "status", hidden: true },
    h("span", { class: "listening-mic" }, icon("mic")),
    h("span", null, "Listening…"));
  const dictate = dictation(textarea, language, (listening) => {
    if (listening) recorded = true;
    if (listening !== undefined && mic) {
      mic.classList.toggle("listening", listening);
      mic.setAttribute("aria-pressed", listening ? "true" : "false");
      listeningCard.hidden = !listening;
    }
    refresh();
  });
  if (dictate) {
    mic = h("button", { type: "button", class: "icon-button mic", title: "Dictate", "aria-label": "Dictate your speech", "aria-pressed": "false", onClick: () => dictate.toggle() }, icon("mic"));
  }

  textarea.addEventListener("input", refresh);
  textarea.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); onSend(); }
  });

  const el = h("div", { class: "composer-core" },
    listeningCard,
    h("div", { class: "composer-row" }, textarea, mic, send),
    meter);

  return {
    el, textarea, send,
    value: () => textarea.value.trim(),
    recorded: () => recorded,
    clear: () => { dictate?.stop(); recorded = false; textarea.value = ""; refresh(); },
    stop: () => dictate?.stop(),
  };
}

export default function sessionView({ app }) {
  const config = app.pending.session;
  if (!config) {
    queueMicrotask(() => app.goHome());
    return { el: h("div") };
  }
  const prefs = store.prefs();
  const mode = config.mode;
  const congress = mode === "Congress";
  const team = mode === "Team vs AI";
  const judged = isJudged(mode);
  const multiplayer = isMultiplayer(mode);
  const userName = app.user.username;
  const userStance = config.userSide === "Affirmative" ? "Pro" : "Con";
  const userIsAuthor = config.userSide === "Affirmative";

  const s = {
    messages: [], thinking: false, error: "", ready: false,
    remaining: 0, timerRunning: false, inquiryPending: false, floorSpeaking: false, finished: false, listening: null,
  };
  let voice = null;
  let disarmTimer = 0;
  let lastCongressIndex = 0;
  let lastCount = -1;
  let destroyed = false;

  const step = () => (team ? teamStep(s.messages.length) : null);
  const congressIndex = () => s.messages.filter((m) => ["speech", "amendment"].includes(effectiveKind(m))).length;
  const segment = () => (congress ? congressSegment(congressIndex()) : null);
  const openFloor = () => congress && congressIsOpenFloor(congressIndex());
  const userTurnInCongress = () => {
    const seg = segment();
    return seg ? seg.stance === userStance : openFloor() && s.floorSpeaking;
  };
  const activeSegment = () => segment() || (s.floorSpeaking ? FLOOR_SPEECH : null);
  const clockText = () => {
    const v = Math.abs(s.remaining);
    return `${s.remaining < 0 ? "+" : ""}${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`;
  };

  function currentParticipant() {
    if (!multiplayer || !config.participants.length) return null;
    const st = step();
    if (st) return st.slot === "ai" ? null : config.participants[st.slot % config.participants.length];
    return config.participants[s.messages.length % config.participants.length];
  }

  function awaitingAI() {
    if (s.listening) return true;
    if (congress) {
      const seg = segment();
      return seg ? seg.stance !== userStance : false;
    }
    return step()?.slot === "ai";
  }

  function crossfirePrompt() {
    const st = step();
    if (!st || st.kind !== "crossfireAnswer") return null;
    const asked = [...s.messages].reverse().find((m) => effectiveKind(m) === "crossfireQuestion");
    if (!asked) return null;
    const list = questionsIn(asked.text);
    const answered = s.messages.filter((m) => effectiveKind(m) === "crossfireAnswer").length;
    return answered < list.length ? { index: answered + 1, total: list.length, text: list[answered] } : null;
  }

  const showComposer = () => !congress || userTurnInCongress();

  function placeholder() {
    if (crossfirePrompt()) return "Answer live…";
    const p = currentParticipant();
    if (p) return `${p.name}'s speech…`;
    const seg = activeSegment();
    if (seg) return `${seg.title}…`;
    return "Type your argument…";
  }

  function showAnalysis() {
    box.stop();
    stopSpeaking();
    el.className = "page analysis";
    replace(el, analysisPage({ onBack: hideAnalysis, onRerecord: rerecord }));
    window.scrollTo(0, 0);
    reveal(el);
  }

  function hideAnalysis() {
    el.className = "page narrow session";
    replace(el, sessionParts);
    update();
    window.scrollTo(0, document.documentElement.scrollHeight);
  }

  const headerRegion = h("div", { class: "session-header" });
  const transcriptRegion = h("div", { class: "transcript", "aria-live": "polite" });
  const bottomRegion = h("div", { class: "composer" });
  const actions = h("div", { class: "page-actions" });

  const box = composer({ language: config.language, placeholder: placeholder(), onSend: send, onInput: () => updateComposer() });
  const crossfireBox = h("div");
  const inquiryNote = h("div");
  const clockBox = h("div");

  function renderClock() {
    const seg = activeSegment();
    if (!congress || !seg || !userTurnInCongress()) return replace(clockBox);
    const over = s.remaining < 0;
    const fill = Math.max(0, Math.min(100, (s.remaining / seg.seconds) * 100));
    replace(clockBox, h("section", { class: "card speech-clock", "aria-label": "Speech clock" },
      h("div", { class: "speech-clock-head" },
        h("strong", null, `Your ${seg.title.toLowerCase()}`),
        h("button", { type: "button", class: "icon-button mic", "aria-label": s.timerRunning ? "Pause the clock" : "Start the clock", onClick: () => { s.timerRunning = !s.timerRunning; renderClock(); } },
          icon(s.timerRunning ? "pause" : "play"))),
      h("div", { class: `speech-clock-time${over ? " over" : ""}`, role: "timer" }, clockText()),
      h("div", { class: `bar${over ? " low" : ""}` }, h("div", { class: "bar-fill", style: { width: `${fill}%` } }))));
  }

  function banner() {
    const p = currentParticipant();
    if (p) {
      const cf = crossfirePrompt();
      return h("div", { class: "banner" }, icon(cf ? "question" : "user"),
        cf ? `Crossfire — ${p.name} answers question ${cf.index} of ${cf.total}` : `Now speaking: ${p.name} · ${p.side} · ${p.role}`);
    }
    if (congress) {
      if (s.listening) return h("div", { class: "banner" }, icon("speaker"), `${s.listening.speaker} has the floor — listen to the full speech`);
      const seg = activeSegment();
      if (!seg) return h("div", { class: "banner" }, icon("flag"), "Main speeches complete — the floor is open");
      const mine = userTurnInCongress();
      return h("div", { class: "banner" }, icon(mine ? "mic" : "user"),
        mine ? `You — ${seg.title} (${seg.stance})` : `AI member — ${seg.title} (${seg.stance}, ${seg.clock})`);
    }
    return h("div", { class: "subtext small" }, `${mode} · ${config.difficulty} · ${config.language}`);
  }

  function renderHeader() {
    replace(headerRegion, topicBox(congress ? config.committee : "Resolution", config.topic, banner()));
    replace(actions,
      congress ? h("button", { type: "button", class: "button secondary compact", disabled: s.thinking || s.inquiryPending || Boolean(s.listening), onClick: openInquiry }, icon("hand"), "Point of inquiry") : null,
      h("button", { type: "button", class: "button primary compact", disabled: s.thinking, onClick: endTapped }, judged || team || congress ? "End Round" : "End Debate"));
  }

  function grounding() {
    return h("section", { class: "card grounding stack" },
      icon("heart", "icon accent big-icon"),
      h("h2", null, "Before you start"),
      h("p", null, "Nobody is watching. Nothing here is graded. This is practice, and every round makes the next one easier."),
      h("ol", { class: "steps" },
        h("li", null, "Breathe in for four counts, hold for four, out for four. Twice."),
        h("li", null, "Say your first point to yourself in one plain sentence."),
        h("li", null, "Remember you can take as long as you want between turns. There's no timer.")),
      h("button", { type: "button", class: "button primary", onClick: () => { s.ready = true; update(); box.textarea.focus(); } }, "I'm ready"));
  }

  function renderTranscript() {
    if (config.lowPressure && !s.ready && !multiplayer) {
      replace(transcriptRegion, grounding());
      return;
    }
    replace(transcriptRegion,
      s.messages.map((m) => [
        messageBubble(m, mode, { language: config.language, showMetrics: prefs.showFillerMeter }),
        m.recorded ? h("button", { type: "button", class: "button secondary compact report-open", onClick: showAnalysis }, icon("sparkle"), "View recording analysis") : null]),
      s.thinking ? h("p", { class: "subtext thinking" }, h("span", { class: "spinner" }), "Thinking…") : null,
      s.error ? h("div", { class: "card error-card" },
        h("p", { class: "error" }, s.error),
        judged ? null : h("button", { type: "button", class: "button secondary compact", onClick: retry }, "Retry")) : null);
  }

  function updateComposer() {
    const cf = crossfirePrompt();
    replace(crossfireBox, cf ? h("div", { class: "card tint crossfire-prompt" }, crossfireLabel(cf)) : null);
    replace(inquiryNote, s.inquiryPending ? h("p", { class: "subtext small" }, icon("hand"), "The parliamentarian is looking that up…") : null);
    box.textarea.placeholder = placeholder();
    box.send.disabled = s.thinking || awaitingAI() || !box.value();
  }

  const listenFill = h("div", { class: "bar-fill", style: { width: "0%" } });
  const listenTitle = h("strong");
  const listenNote = h("span", { class: "subtext small" });
  const skipButton = h("button", { type: "button", class: "button secondary compact", onClick: skipTapped });
  const keepButton = h("button", { type: "button", class: "button secondary compact", onClick: () => disarm() }, "Keep listening");
  const listenCard = h("section", { class: "card listen-card", "aria-label": "Speech in progress" },
    h("div", { class: "listen-head" },
      h("span", { class: "listen-icon" }, icon("speaker")),
      h("div", { class: "stack-sm", style: { gap: "2px" } }, listenTitle, listenNote)),
    h("div", { class: "bar" }, listenFill),
    h("div", { class: "button-row start" }, skipButton, keepButton));

  function paintListening() {
    const l = s.listening;
    if (!l) return;
    listenTitle.textContent = `${l.speaker} has the floor`;
    listenFill.style.width = `${Math.round(l.progress * 100)}%`;
    listenNote.textContent = l.armed
      ? "You'll miss the rest of their speech, and you need it to rebut. Tap Skip anyway to confirm."
      : l.silent
        ? "Audio isn't available in this browser right now, so read along in the speech above. Your clock starts when it ends."
        : "Listen to the whole speech before you answer, just like in a real chamber. Your clock starts when it ends.";
    skipButton.textContent = l.armed ? "Skip anyway" : "Skip speech";
    skipButton.classList.toggle("danger", l.armed);
    keepButton.hidden = !l.armed;
  }

  function disarm() {
    clearTimeout(disarmTimer);
    if (s.listening) s.listening.armed = false;
    paintListening();
  }

  function skipTapped() {
    if (!s.listening) return;
    if (!s.listening.armed) {
      s.listening.armed = true;
      clearTimeout(disarmTimer);
      disarmTimer = setTimeout(disarm, 6000);
      return paintListening();
    }
    finishListening();
  }

  function listenTo(text, speaker) {
    s.timerRunning = false;
    s.listening = { speaker, progress: 0, armed: false };
    voice = speak(text, config.language, {
      onProgress: (p) => { if (s.listening) { s.listening.progress = p; paintListening(); } },
      onEnd: finishListening,
      onSilent: () => { if (s.listening && !s.listening.silent) { s.listening.silent = true; paintListening(); } },
    });
  }

  function finishListening() {
    if (!s.listening || destroyed) return;
    clearTimeout(disarmTimer);
    voice?.stop();
    voice = null;
    s.listening = null;
    resetClock();
    update();
    advanceIfAITurn();
  }

  function renderBottom() {
    if (s.listening) {
      box.stop();
      paintListening();
      return replace(bottomRegion, listenCard);
    }
    if (config.lowPressure && !s.ready && !multiplayer) return replace(bottomRegion);
    if (openFloor() && !s.floorSpeaking) {
      box.stop();
      return replace(bottomRegion,
        h("div", { class: "button-row" },
          h("button", { type: "button", class: "button primary", onClick: () => { s.floorSpeaking = true; resetClock(); update(); box.textarea.focus(); } }, icon("mic"), "Speak again (2:00)"),
          h("button", { type: "button", class: "button secondary", disabled: s.thinking, onClick: yieldFloor }, icon("wave"), "Yield the floor")));
    }
    if (!showComposer()) {
      box.stop();
      return replace(bottomRegion);
    }
    if (!bottomRegion.contains(box.el)) replace(bottomRegion, clockBox, crossfireBox, box.el, inquiryNote);
    renderClock();
    updateComposer();
  }

  function update() {
    if (destroyed) return;
    const index = congressIndex();
    if (index !== lastCongressIndex) { lastCongressIndex = index; resetClock(); }
    renderHeader();
    renderTranscript();
    renderBottom();
    const count = s.messages.length + (s.thinking ? 0.5 : 0) + (s.error ? 0.25 : 0);
    if (count !== lastCount) {
      lastCount = count;
      requestAnimationFrame(() => { if (transcriptRegion.isConnected) window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" }); });
    }
  }

  function resetClock() {
    if (s.listening) { s.timerRunning = false; return; }
    const seg = activeSegment();
    if (!congress || !seg || !userTurnInCongress()) { s.timerRunning = false; return; }
    s.remaining = seg.seconds;
    s.timerRunning = true;
  }

  const ticker = setInterval(() => {
    if (!s.timerRunning || !userTurnInCongress()) return;
    s.remaining -= 1;
    renderClock();
  }, 1000);

  function send() {
    const text = box.value();
    if (!text || s.thinking || awaitingAI()) return;
    const recorded = box.recorded();
    box.clear();
    const p = currentParticipant();
    let message;
    if (congress) message = { id: newId(), role: "user", text, speaker: userName, kind: "speech" };
    else if (p) message = { id: newId(), role: p.isUser ? "user" : "assistant", text, speaker: p.name, kind: step()?.kind || "speech" };
    else message = { id: newId(), role: "user", text, speaker: userName, kind: "speech" };
    if (recorded) message.recorded = true;
    s.messages.push(message);
    s.floorSpeaking = false;
    runStatCheck(message);
    if (recorded && !team && !congress && !judged) {
      update();
      showAnalysis();
    } else if (team || congress) {
      s.timerRunning = false;
      update();
      advanceIfAITurn();
    } else if (!judged) {
      requestReply();
    } else {
      update();
    }
  }

  function advanceIfAITurn() {
    if (s.thinking || s.listening || destroyed) return;
    if (congress) {
      const seg = segment();
      if (seg && seg.stance !== userStance) requestReply();
      return;
    }
    const st = step();
    if (!team || !st || st.slot !== "ai") return;
    if (st.kind === "crossfireQuestion") requestCrossfire(); else requestReply();
  }

  function retry() {
    const last = s.messages[s.messages.length - 1];
    if ((mode === "Debate" || mode === "Coach") && last?.role === "user") requestReply();
    else advanceIfAITurn();
  }

  function yieldFloor() {
    if (s.thinking) return;
    s.floorSpeaking = false;
    requestReply("amendment");
  }

  async function runStatCheck(message) {
    if (!containsStatistic(message.text)) return;
    try {
      message.statCheck = await api.ai.statCheck(message.text, config.topic, config.language);
      update();
    } catch {}
  }

  async function requestCrossfire() {
    s.error = "";
    s.thinking = true;
    update();
    try {
      const questions = await api.ai.crossfire(config, s.messages);
      const text = questions.map((q, i) => `${i + 1}. ${q}`).join("\n");
      s.messages.push({ id: newId(), role: "assistant", text, speaker: "Opposing team", kind: "crossfireQuestion" });
      if (prefs.readAloud) speak(text, config.language);
    } catch (e) {
      s.error = e.message;
    }
    s.thinking = false;
    update();
  }

  async function requestReply(kind = "speech") {
    s.error = "";
    s.thinking = true;
    update();
    try {
      const reply = await api.ai.turn(config, s.messages);
      const speaker = team ? "Opposing team" : congress ? (userIsAuthor ? "Opposing member" : "Bill sponsor") : modeInfo(mode).assistantLabel;
      s.messages.push({ id: newId(), role: "assistant", text: reply, speaker, kind });
      if (congress && !destroyed) listenTo(reply, speaker);
      else if (prefs.readAloud && !destroyed) speak(reply, config.language);
    } catch (e) {
      s.error = e.message;
    }
    s.thinking = false;
    if (congress) resetClock();
    update();
    if (!s.error) advanceIfAITurn();
  }

  function rerecord() {
    box.stop();
    rerecordDialog({ language: config.language });
  }

  function openInquiry() {
    modal("Point of inquiry", (close) => {
      const field = h("textarea", { class: "field", rows: "4", placeholder: "e.g. What is the current federal deficit? Or: is a motion to amend in order right now?", "aria-label": "Your inquiry" });
      const submit = h("button", { type: "button", class: "button primary", disabled: true, onClick: () => { close(); askInquiry(field.value); } }, "Rise to inquiry");
      field.addEventListener("input", () => { submit.disabled = s.inquiryPending || !field.value.trim(); });
      requestAnimationFrame(() => field.focus());
      return h("div", { class: "stack" },
        field, submit);
    });
  }

  async function askInquiry(question) {
    const text = question.trim();
    if (!text) return;
    s.inquiryPending = true;
    s.messages.push({ id: newId(), role: "user", text, speaker: userName, kind: "inquiry" });
    update();
    try {
      const ruling = await api.ai.inquiry(config, text, s.messages);
      s.messages.push({ id: newId(), role: "assistant", text: ruling, speaker: "Parliamentarian", kind: "ruling" });
      if (prefs.readAloud && !destroyed) speak(ruling, config.language);
    } catch (e) {
      s.error = e.message;
    }
    s.inquiryPending = false;
    update();
  }

  function endTapped() {
    let enough;
    if (judged) {
      const spoken = new Set(s.messages.map((m) => m.speaker));
      enough = config.participants.every((p) => spoken.has(p.name));
    } else {
      enough = s.messages.some((m) => m.role === "user" && effectiveKind(m) !== "inquiry");
    }
    if (enough) {
      confirmDialog(judged ? "End the round and send it to the judge?" : "End this session and get your feedback?", judged || team || congress ? "End Round" : "End Debate", finish);
    } else if (!s.messages.length) {
      app.goHome(congress ? "congress" : "debate");
    } else {
      s.error = judged ? "Every debater needs to speak at least once before the judge can decide." : "Give at least one speech first.";
      update();
    }
  }

  function finish() {
    stopSpeaking();
    s.finished = true;
    app.pending.feedback = { config, transcript: s.messages.map((m) => ({ ...m })) };
    app.pending.session = null;
    app.guard = null;
    app.go("/feedback");
  }

  const sessionParts = [pageHeader({ title: TITLES[mode], actions: [actions] }), headerRegion, transcriptRegion, bottomRegion];
  const el = h("div", { class: "page narrow session" }, sessionParts);

  document.body.classList.add("focus-mode");
  resetClock();
  update();
  advanceIfAITurn();
  queueMicrotask(() => {
    app.guard = () => (!s.finished && s.messages.length ? "Leave this round? Your speeches so far won't be saved." : null);
  });

  return {
    el,
    title: TITLES[mode],
    destroy() {
      destroyed = true;
      clearInterval(ticker);
      clearTimeout(disarmTimer);
      voice?.stop();
      box.stop();
      document.body.classList.remove("focus-mode");
    },
  };
}
