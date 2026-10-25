const CODE_KEY = "verbatim.accessCode";

export function accessCode() {
  try { return localStorage.getItem(CODE_KEY) || ""; } catch { return ""; }
}

function setAccessCode(code) {
  try { localStorage.setItem(CODE_KEY, code); } catch {}
}

async function request(path, body) {
  let res;
  try {
    res = await fetch(path, body === undefined
      ? { cache: "no-store" }
      : { method: "POST", headers: { "content-type": "application/json", "x-access-code": accessCode() }, body: JSON.stringify(body) });
  } catch {
    throw new Error("Couldn't reach the Verbatim server. Check that it's running and try again.");
  }
  const json = await res.json().catch(() => null);
  if (!res.ok) throw new Error(json?.error || `Server error (${res.status})`);
  return json;
}

export const status = () => request("/api/status");

export async function unlock(code) {
  setAccessCode(code);
  await request("/api/unlock", {});
}

export const voice = async (text) => (await request("/api/voice", { text })).audio;

const wire = (messages) => messages.map(({ role, text, speaker, kind }) => ({ role, text, speaker, kind }));

export const ai = {
  turn: async (config, history) => (await request("/api/turn", { config, history: wire(history) })).text,
  crossfire: async (config, history) => (await request("/api/crossfire", { config, history: wire(history) })).questions,
  statCheck: async (text, topic, language) => (await request("/api/statcheck", { text, topic, config: { language } })).text,
  feedback: async (config, transcript) => (await request("/api/feedback", { config, history: wire(transcript) })).feedback,
  judge: async (config, transcript) => (await request("/api/judge", { config, history: wire(transcript) })).decision,
  inquiry: async (config, question, history) => (await request("/api/inquiry", { config, question, history: wire(history) })).text,
  statLookup: async (question, committee, language) => (await request("/api/statlookup", { question, committee, config: { language } })).text,
};

export const rooms = {
  create: (config, hostName) => request("/rooms", {
    format: config.mode, topic: config.topic, language: config.language, difficulty: config.difficulty,
    judgePreset: config.judgePreset, judgeInstructions: "", hostSide: config.userSide, hostName,
  }),
  join: (code, name) => request(`/rooms/${encodeURIComponent(code.toUpperCase())}/join`, { name }),
  fetch: async (code) => (await request(`/rooms/${encodeURIComponent(code.toUpperCase())}`)).room,
  speak: async (code, playerId, text) => (await request(`/rooms/${code}/speeches`, { playerId, text })).room,
  statCheck: async (code, playerId, speechId, statCheck) => (await request(`/rooms/${code}/statcheck`, { playerId, speechId, statCheck })).room,
  aiSpeech: async (code, hostId, speaker, text) => (await request(`/rooms/${code}/ai`, { playerId: hostId, speaker, text })).room,
  setStatus: async (code, hostId, status) => (await request(`/rooms/${code}/status`, { playerId: hostId, status })).room,
  postResult: async (code, hostId, decision, feedback) => (await request(`/rooms/${code}/result`, { playerId: hostId, decision, feedback })).room,
};
