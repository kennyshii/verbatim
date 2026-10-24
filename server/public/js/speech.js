import { speechCode } from "./data.js";

export function speak(text, language = "English") {
  if (!("speechSynthesis" in window)) return;
  stop();
  const utterance = new SpeechSynthesisUtterance(String(text).replace(/\*\*/g, "").replace(/#/g, ""));
  const code = speechCode(language);
  utterance.lang = code;
  const voice = speechSynthesis.getVoices().find((v) => v.lang === code) || speechSynthesis.getVoices().find((v) => v.lang.startsWith(code.slice(0, 2)));
  if (voice) utterance.voice = voice;
  utterance.rate = 0.95;
  speechSynthesis.speak(utterance);
}

export function stop() {
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
