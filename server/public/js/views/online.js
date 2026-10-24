import { isJudged, namesOn, questionsIn } from "../data.js";
import * as api from "../api.js";
import { analyzeTurns, containsStatistic } from "../metrics.js";
import { speak, stop as stopSpeaking } from "../speech.js";
import * as store from "../store.js";
import { confirmDialog, feedbackSections, h, icon, judgeDecision, meterBar, pageHeader, replace, sectionLabel, subtext, topicBox } from "../ui.js";
import { messageBubble } from "./bubble.js";
import { composer, crossfireLabel } from "./session.js";

const SEATS = "verbatim.seats";
const SAVED = "verbatim.savedRooms";

function readJSON(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; }
}
function writeJSON(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch {}
}

export function saveSeat(code, playerId) {
  writeJSON(SEATS, { ...readJSON(SEATS, {}), [code.toUpperCase()]: playerId });
}
const seatFor = (code) => readJSON(SEATS, {})[code.toUpperCase()];

const crossfireKind = (kind) => (kind === "crossfireQ" ? "crossfireQuestion" : kind === "crossfireA" ? "crossfireAnswer" : "speech");

export function joinForm(app, onJoined, presetCode = "") {
  const code = h("input", { type: "text", class: "field code-input", placeholder: "ABC123", maxlength: "6", autocapitalize: "characters", spellcheck: "false", "aria-label": "Room code", value: presetCode });
  const name = h("input", { type: "text", class: "field", placeholder: "Shown to the other debaters", "aria-label": "Your name", value: app.user?.username || "" });
  const error = h("p", { class: "error", role: "alert" });
  const button = h("button", { type: "submit", class: "button primary" }, "Join round");
  const sync = () => { button.disabled = code.value.trim().length < 4 || !name.value.trim(); };
  code.addEventListener("input", () => { code.value = code.value.toUpperCase(); sync(); });
  name.addEventListener("input", sync);
  sync();

  async function submit(e) {
    e.preventDefault();
    button.disabled = true;
    button.textContent = "Joining…";
    error.textContent = "";
    try {
      const { room, playerId } = await api.rooms.join(code.value.trim(), name.value.trim());
      saveSeat(room.code, playerId);
      onJoined(room.code);
    } catch (err) {
      error.textContent = err.message;
    }
    button.textContent = "Join round";
    sync();
  }

  requestAnimationFrame(() => (presetCode ? name : code).focus());
  return h("form", { class: "stack", onSubmit: submit },
    h("label", { class: "field-label" }, "Room code"), code,
    h("label", { class: "field-label" }, "Your name"), name,
    error, button,
    subtext("Ask the host for the six-character code on their screen. No account needed.", "small"));
}

export function joinPageView({ query, app }) {
  const el = h("div", { class: "page narrow" },
    pageHeader({ title: "Join a round", back: app.user ? { href: "#/debate", label: "Debate" } : { href: "#/login", label: "Log in" } }),
    h("div", { class: "card" }, joinForm(app, (code) => app.go(`/room/${code}`), (query.get("code") || "").toUpperCase())));
  return { el, title: "Join a round" };
}

export function roomView({ params, app }) {
  const code = params[0].toUpperCase();
  const playerId = seatFor(code);
  if (!playerId) {
    const el = h("div", { class: "page narrow" },
      pageHeader({ title: "Join a round", back: { href: app.user ? "#/debate" : "#/login", label: "Back" } }),
      h("div", { class: "card stack" },
        subtext(`You haven't joined room ${code} in this browser yet.`),
        joinForm(app, () => location.reload(), code)));
    return { el, title: "Join a round" };
  }

  const prefs = store.prefs();
  let room = null;
  let snapshot = "";
  let error = "";
  let sending = false;
  let aiInFlight = false;
  let judgingInFlight = false;
  let saved = readJSON(SAVED, []).includes(`${code}:${playerId}`);
  let destroyed = false;
  let lastSpeeches = -1;
  const spokenAI = new Set();

  const isHost = () => room?.hostId === playerId;
  const me = () => room?.players.find((p) => p.id === playerId);
  const myTurn = () => room?.expected?.type === "player" && room.expected.playerId === playerId;
  const playerName = (id) => room.players.find((p) => p.id === id);
  const sorted = () => [...room.players].sort((a, b) => a.slot - b.slot);

  function crossfirePrompt() {
    if (!room || !myTurn() || room.expected?.kind !== "crossfireA") return null;
    const asked = [...room.speeches].reverse().find((s) => s.kind === "crossfireQ");
    if (!asked) return null;
    const list = questionsIn(asked.text);
    const answered = room.expected.questionIndex || 0;
    return answered < list.length ? { index: answered + 1, total: list.length, text: list[answered] } : null;
  }

  function config() {
    const self = me();
    if (!room || !self) return null;
    return {
      kind: "debate", topic: room.topic, language: room.language, difficulty: room.difficulty, mode: room.format,
      userSide: self.side, judgePreset: room.judgePreset, online: true, committee: "", billText: "",
      lowPressure: prefs.lowPressure, plainLanguage: prefs.plainLanguage,
      participants: sorted().map((p) => ({ name: p.name, side: p.side, role: p.role, isUser: p.id === playerId })),
    };
  }

  function transcript() {
    if (!room) return [];
    return room.speeches.map((s) => ({
      id: s.id,
      role: s.playerId === playerId || (room.format === "Team vs AI" && s.playerId) ? "user" : "assistant",
      text: s.text, speaker: s.speaker, statCheck: s.statCheck, kind: crossfireKind(s.kind),
    }));
  }

  const actions = h("div", { class: "page-actions" });
  const headerRegion = h("div");
  const mainRegion = h("div", { class: "stack-lg" });
  const bannerRegion = h("div");
  const transcriptRegion = h("div", { class: "transcript", "aria-live": "polite" });
  const crossfireBox = h("div");
  const box = composer({ language: () => room?.language || "English", placeholder: "Your speech…", onSend: () => sendSpeech(), onInput: () => syncComposer() });
  const composerRegion = h("div", { class: "composer" }, crossfireBox, box.el);
  let liveMounted = false;

  function renderActions() {
    const leave = () => { stopSpeaking(); app.user ? app.goHome() : app.go("/join"); };
    replace(actions,
      room?.status === "live" && isHost() ? h("button", { type: "button", class: "button secondary compact", onClick: () => confirmDialog("End the round now?", "End Round", endRound) }, "End Round") : null,
      room?.status === "done" ? h("button", { type: "button", class: "button secondary compact", onClick: leave }, "Done") : null,
      !room || room.status === "lobby" ? h("button", { type: "button", class: "button secondary compact", onClick: leave }, "Leave") : null);
  }

  function renderHeader() {
    replace(headerRegion, room
      ? topicBox("Resolution", room.topic, h("div", { class: "subtext small" }, h("code", { class: "room-code-inline" }, room.code), ` · ${room.format} · ${room.difficulty} · ${room.language}`))
      : null);
  }

  function lobby() {
    const shareLink = `${location.origin}/#/join?code=${room.code}`;
    const shareText = `Join my debate round in Verbatim — code ${room.code}. Resolution: ${room.topic}`;
    const shareButton = h("button", { type: "button", class: "button secondary compact", onClick: async () => {
      if (navigator.share) {
        try { await navigator.share({ title: "Verbatim round", text: shareText, url: shareLink }); } catch {}
        return;
      }
      try {
        await navigator.clipboard.writeText(`${shareText}\n${shareLink}`);
        shareButton.textContent = "Link copied";
      } catch {
        shareButton.textContent = shareLink;
      }
    } }, icon("share"), "Share code");

    const open = Array.from({ length: Math.max(0, room.capacity - room.players.length) });
    return [
      h("section", { class: "card stack-sm" },
        h("div", { class: "subtext small" }, "Room code"),
        h("div", { class: "room-code" }, room.code),
        subtext(`Share this code. Others open ${location.host}, choose "Join a round with a code", and enter it with their name.`, "small"),
        h("div", null, shareButton)),
      h("section", { class: "stack-sm" },
        sectionLabel(`Debaters (${room.players.length}/${room.capacity})`),
        sorted().map((p) => h("div", { class: "player-row" },
          icon(p.id === room.hostId ? "crown" : "user", "icon accent"),
          h("span", { class: p.id === playerId ? "strong grow" : "grow" }, p.name),
          h("span", { class: "subtext small" }, `${p.side} · ${p.role}`))),
        open.map(() => h("div", { class: "player-row waiting" }, icon("clock", "icon muted"), h("span", { class: "subtext" }, "Waiting for a debater to join…")))),
      isHost()
        ? h("button", { type: "button", class: "button primary", disabled: room.players.length < room.capacity, onClick: () => setStatus("live") }, room.players.length >= room.capacity ? "Start the round" : "Waiting for everyone…")
        : subtext("The host starts the round once everyone has joined."),
      error ? h("p", { class: "error" }, error) : null,
    ];
  }

  function banner() {
    const cf = crossfirePrompt();
    const self = me();
    let text;
    if (cf) text = `Crossfire — your turn, question ${cf.index} of ${cf.total}`;
    else if (myTurn()) text = `Your turn — ${self?.side || ""} · ${self?.role || ""}`;
    else if (room.expected?.kind === "crossfireQ") text = "Opposing team is preparing crossfire questions…";
    else if (room.expected?.type === "ai") text = "Opposing team is responding…";
    else if (room.expected?.playerId) {
      const p = playerName(room.expected.playerId);
      text = room.expected.kind === "crossfireA" ? `Crossfire — ${p?.name} is answering` : `Now speaking: ${p?.name} · ${p?.side} · ${p?.role}`;
    } else text = "Waiting…";
    return h("div", { class: `banner wide${myTurn() ? " mine" : ""}` }, icon(myTurn() ? "mic" : "user"), text);
  }

  function renderLive() {
    replace(bannerRegion, banner());
    const cfg = config();
    replace(transcriptRegion,
      room.speeches.length ? null : h("p", { class: "subtext intro" }, room.format === "Team vs AI"
        ? "The case speaker opens, the AI opposing team answers, then crossfire: the AI asks your team three questions you answer live, one at a time."
        : "The affirmative opens. Each debater speaks from their own device when the banner says it's their turn."),
      transcript().map((m) => messageBubble(m, room.format, { language: cfg?.language, showMetrics: prefs.showFillerMeter })),
      aiInFlight ? h("p", { class: "subtext thinking" }, h("span", { class: "spinner" }), room.expected?.kind === "crossfireQ" ? "Opposing team is preparing crossfire questions…" : "Opposing team is responding…") : null,
      error ? h("p", { class: "error" }, error) : null);
    if (!liveMounted) {
      replace(mainRegion, bannerRegion, transcriptRegion, composerRegion);
      liveMounted = true;
    }
    syncComposer();
    if (room.speeches.length !== lastSpeeches) {
      lastSpeeches = room.speeches.length;
      requestAnimationFrame(() => window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" }));
    }
  }

  function syncComposer() {
    if (!room) return;
    const cf = crossfirePrompt();
    replace(crossfireBox, cf ? h("div", { class: "card tint crossfire-prompt" }, crossfireLabel(cf)) : null);
    box.textarea.disabled = !myTurn();
    box.textarea.placeholder = cf ? "Answer live…" : myTurn() ? "Your speech…" : "Waiting for your turn…";
    box.send.disabled = !myTurn() || sending || !box.value();
  }

  function judging() {
    return h("div", { class: "loading stack" },
      h("div", null, h("span", { class: "spinner" }), isJudged(room.format) ? "The judge is deciding…" : "The coach is reviewing the round…"),
      isHost() ? subtext("Your browser is running the judge for everyone.", "small") : null,
      error ? [h("p", { class: "error" }, error), isHost() ? h("button", { type: "button", class: "button secondary compact", onClick: runJudging }, "Retry") : null] : null);
  }

  function result() {
    const cfg = config();
    const language = cfg?.language || "English";
    return [
      room.result?.decision && cfg
        ? judgeDecision(room.result.decision, { affirmative: namesOn(cfg, "Affirmative"), negative: namesOn(cfg, "Negative"), language })
        : room.result?.feedback
          ? feedbackSections(room.result.feedback, { language })
          : subtext("The round ended without a result."),
      h("section", { class: "card stack" },
        sectionLabel("Delivery"),
        sorted().map((p) => meterBar(analyzeTurns(room.speeches.filter((s) => s.playerId === p.id).map((s) => s.text)), { title: `${p.name} — presentational accuracy` }))),
      saved ? subtext("Saved to your progress.", "small") : !app.user ? subtext("Log in before joining a round to save it to your progress.", "small") : null,
      h("h2", { class: "accent-heading" }, "Transcript"),
      h("div", { class: "transcript" }, transcript().map((m) => messageBubble(m, room.format, { language }))),
    ];
  }

  function render() {
    if (destroyed) return;
    renderActions();
    renderHeader();
    document.body.classList.toggle("focus-mode", room?.status === "live");
    if (!room) {
      replace(mainRegion, error ? h("p", { class: "error" }, error) : h("div", { class: "loading" }, h("span", { class: "spinner" }), `Connecting to room ${code}…`));
      liveMounted = false;
      return;
    }
    if (room.status === "live") return renderLive();
    if (liveMounted) box.stop();
    liveMounted = false;
    if (room.status === "lobby") replace(mainRegion, lobby());
    else if (room.status === "judging") replace(mainRegion, judging());
    else {
      saveLocally();
      replace(mainRegion, result());
    }
  }

  function setRoom(latest) {
    const next = JSON.stringify(latest);
    const changed = next !== snapshot;
    snapshot = next;
    room = latest;
    if (changed) render();
    return changed;
  }

  async function poll() {
    while (!destroyed) {
      try {
        const latest = await api.rooms.fetch(code);
        if (setRoom(latest)) await reactToRoom();
      } catch (e) {
        if (!room) { error = e.message; render(); }
      }
      await new Promise((r) => setTimeout(r, 2000));
    }
  }

  async function reactToRoom() {
    if (!room || destroyed) return;
    const last = room.speeches[room.speeches.length - 1];
    if (prefs.readAloud && last && !last.playerId && !spokenAI.has(last.id)) {
      spokenAI.add(last.id);
      speak(last.text, room.language);
    }
    if (!isHost()) return;
    if (room.status === "live" && room.format === "Team vs AI" && room.expected?.type === "ai" && !aiInFlight) {
      if (room.expected.kind === "crossfireQ") await runCrossfire(); else await runTeamAI();
    }
    if (room.status === "judging" && !judgingInFlight && !room.result) await runJudging();
  }

  async function sendSpeech() {
    const text = box.value();
    const cfg = config();
    if (!text || !cfg || sending || !myTurn()) return;
    sending = true;
    error = "";
    syncComposer();
    try {
      const updated = await api.rooms.speak(code, playerId, text);
      box.clear();
      setRoom(updated);
      const speech = [...updated.speeches].reverse().find((s) => s.playerId === playerId);
      if (containsStatistic(text) && speech && (speech.kind || "speech") === "speech") {
        api.ai.statCheck(text, cfg.topic, cfg.language)
          .then((verdict) => api.rooms.statCheck(code, playerId, speech.id, verdict))
          .then((r) => setRoom(r))
          .catch(() => {});
      }
      await reactToRoom();
    } catch (e) {
      error = e.message;
      render();
    }
    sending = false;
    syncComposer();
  }

  async function runTeamAI() {
    const cfg = config();
    if (!cfg) return;
    aiInFlight = true;
    error = "";
    render();
    try {
      const reply = await api.ai.turn(cfg, transcript());
      setRoom(await api.rooms.aiSpeech(code, playerId, "Opposing team", reply));
    } catch (e) {
      error = `AI turn failed: ${e.message}`;
    }
    aiInFlight = false;
    render();
  }

  async function runCrossfire() {
    const cfg = config();
    if (!cfg) return;
    aiInFlight = true;
    error = "";
    render();
    try {
      const questions = await api.ai.crossfire(cfg, transcript());
      setRoom(await api.rooms.aiSpeech(code, playerId, "Opposing team", questions.map((q, i) => `${i + 1}. ${q}`).join("\n")));
    } catch (e) {
      error = `Crossfire failed: ${e.message}`;
    }
    aiInFlight = false;
    render();
  }

  async function setStatus(status) {
    error = "";
    try {
      setRoom(await api.rooms.setStatus(code, playerId, status));
    } catch (e) {
      error = e.message;
      render();
    }
  }

  async function endRound() {
    const speakers = new Set(room.speeches.map((s) => s.playerId).filter(Boolean));
    if (!room.players.every((p) => speakers.has(p.id))) {
      error = "Every debater needs to speak at least once first.";
      return render();
    }
    await setStatus("judging");
    await runJudging();
  }

  async function runJudging() {
    const cfg = config();
    if (!isHost() || !cfg || judgingInFlight) return;
    judgingInFlight = true;
    error = "";
    render();
    try {
      if (isJudged(room.format)) {
        const decision = await api.ai.judge(cfg, transcript());
        setRoom(await api.rooms.postResult(code, playerId, decision, null));
      } else {
        const feedback = await api.ai.feedback(cfg, transcript());
        setRoom(await api.rooms.postResult(code, playerId, null, feedback));
      }
    } catch (e) {
      error = e.message;
    }
    judgingInFlight = false;
    render();
  }

  function saveLocally() {
    const cfg = config();
    if (saved || !app.user || !cfg || !room.result) return;
    const feedback = room.result.decision ? { type: "judge", decision: room.result.decision } : room.result.feedback ? { type: "coach", feedback: room.result.feedback } : null;
    if (!feedback) return;
    try {
      store.saveSession(app.user.id, cfg, transcript(), feedback);
      saved = true;
      writeJSON(SAVED, [...readJSON(SAVED, []), `${code}:${playerId}`]);
    } catch (e) {
      error = e.message;
    }
  }

  const el = h("div", { class: "page narrow session" },
    pageHeader({ title: "Online round", actions: [actions] }),
    headerRegion, mainRegion);

  render();
  poll();

  return {
    el,
    title: `Room ${code}`,
    destroy() {
      destroyed = true;
      box.stop();
      document.body.classList.remove("focus-mode");
    },
  };
}
