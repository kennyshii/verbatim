import * as api from "./api.js";
import { speechCode } from "./data.js";

const clean = (text) => String(text).replace(/\*\*/g, "").replace(/#/g, "").replace(/\s+/g, " ").trim();
const sentences = (text) => text.match(/[^.!?]+[.!?]+["”’)]*\s*|[^.!?]+$/g) || [text];

function chunks(text) {
  const out = [];
  let current = "";
  for (const sentence of sentences(text)) {
    const limit = out.length ? 700 : 220;
    if (current && (current + sentence).length > limit) {
      out.push(current.trim());
      current = "";
    }
    current += sentence;
  }
  if (current.trim()) out.push(current.trim());
  return out;
}

const cache = new Map();
let remoteDownUntil = 0;

function audioFor(text) {
  if (!cache.has(text)) {
    const request = api.voice(text).then((b64) => {
      const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
      return URL.createObjectURL(new Blob([bytes], { type: "audio/wav" }));
    });
    request.catch(() => cache.delete(text));
    cache.set(text, request);
    if (cache.size > 40) cache.delete(cache.keys().next().value);
  }
  return cache.get(text);
}

const PREFERRED_VOICES = ["Eddy", "Reed", "Aaron", "Alex", "Google UK English Male", "Microsoft Andrew", "Microsoft Guy", "Microsoft Brian", "Daniel", "Jorge", "Thomas", "Rocko"];

function localVoice(code) {
  const norm = (v) => v.lang.replace("_", "-");
  const voices = speechSynthesis.getVoices().filter((v) => norm(v).startsWith(code.slice(0, 2)));
  for (const name of PREFERRED_VOICES) {
    const match = voices.find((v) => v.name.startsWith(name) && norm(v) === code) || voices.find((v) => v.name.startsWith(name));
    if (match) return match;
  }
  return voices.find((v) => norm(v) === code) || voices[0] || null;
}

function playAudio(url, session, report) {
  return new Promise((resolve) => {
    const audio = new Audio(url);
    session.audio = audio;
    session.resolve = () => resolve(true);
    audio.ontimeupdate = () => { if (audio.duration) report(audio.currentTime / audio.duration); };
    audio.onended = () => resolve(true);
    audio.onerror = () => resolve(false);
    audio.play().catch(() => resolve(false));
  });
}

function waitFor(text, session, report) {
  const ms = Math.max(1200, text.split(/\s+/).length * 400);
  return new Promise((resolve) => {
    const begin = performance.now();
    const timer = setInterval(() => {
      const f = (performance.now() - begin) / ms;
      report(Math.min(1, f));
      if (f >= 1 || session.stopped) { clearInterval(timer); resolve(); }
    }, 250);
    session.resolve = () => { clearInterval(timer); resolve(); };
  });
}

async function sayLocally(text, code, session, report) {
  const list = sentences(text);
  const voice = "speechSynthesis" in window ? localVoice(code) : null;
  for (let i = 0; i < list.length && !session.stopped; i++) {
    const sub = (f) => report((i + f) / list.length);
    const spoke = "speechSynthesis" in window && await new Promise((resolve) => {
      let started = false;
      speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(list[i]);
      utterance.lang = code;
      if (voice) utterance.voice = voice;
      utterance.pitch = 1.12;
      utterance.rate = 1.02;
      utterance.onstart = () => { started = true; };
      utterance.onend = () => resolve(started);
      utterance.onerror = () => resolve(started);
      session.resolve = () => resolve(true);
      speechSynthesis.speak(utterance);
    });
    if (!spoke && !session.stopped) {
      session.silent = true;
      session.onSilent?.();
      await waitFor(list[i], session, sub);
    }
    sub(1);
  }
}

let active = null;

export function speak(text, language = "English", { onEnd, onProgress, onSilent } = {}) {
  stop();
  const parts = chunks(clean(text));
  const code = speechCode(language);
  const session = { stopped: false, audio: null, resolve: null, silent: false, onSilent };
  active = session;
  const remote = () => Date.now() > remoteDownUntil;
  const fetchPart = (i) => (i < parts.length && remote() ? audioFor(parts[i]) : null);

  (async () => {
    let next = fetchPart(0);
    for (let i = 0; i < parts.length; i++) {
      if (session.stopped) return;
      const pending = next;
      let url = null;
      if (pending) {
        try { url = await pending; } catch { remoteDownUntil = Date.now() + 1_800_000; }
      }
      if (session.stopped) return;
      next = fetchPart(i + 1);
      const report = (f) => onProgress?.(Math.min(1, (i + f) / parts.length));
      const played = url ? await playAudio(url, session, report) : false;
      if (!played && !session.stopped) await sayLocally(parts[i], code, session, report);
    }
    if (session.stopped) return;
    if (active === session) active = null;
    onEnd?.();
  })();

  return { stop: () => { if (active === session) stop(); else session.stopped = true; } };
}

export function stop() {
  if (active) {
    active.stopped = true;
    active.audio?.pause();
    active.resolve?.();
    active = null;
  }
  if ("speechSynthesis" in window && (speechSynthesis.speaking || speechSynthesis.pending)) speechSynthesis.cancel();
}

const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
export const canDictate = Boolean(Recognition);

export function dictation(textarea, language, onUpdate) {
  if (!Recognition) return null;
  let recognition = null;
  let base = "";

  const stopListening = () => recognition?.stop();

  const toggle = () => {
    if (recognition) return stopListening();
    recognition = new Recognition();
    recognition.lang = speechCode(typeof language === "function" ? language() : language);
    recognition.continuous = true;
    recognition.interimResults = true;
    base = textarea.value ? textarea.value.replace(/\s*$/, " ") : "";
    recognition.onresult = (event) => {
      let finalText = "";
      let interim = "";
      for (let i = 0; i < event.results.length; i++) {
        const piece = event.results[i][0].transcript;
        if (event.results[i].isFinal) finalText += piece;
        else interim += piece;
      }
      textarea.value = base + finalText + interim;
      onUpdate();
    };
    recognition.onend = () => {
      recognition = null;
      onUpdate(false);
    };
    recognition.onerror = () => stopListening();
    recognition.start();
    onUpdate(true);
  };

  return { toggle, stop: stopListening, get listening() { return Boolean(recognition); } };
}
