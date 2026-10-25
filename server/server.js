import http from "node:http";
import crypto from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as claude from "./claude.js";

const HERE = path.dirname(fileURLToPath(import.meta.url));
try { process.loadEnvFile(path.join(HERE, ".env")); } catch {}

const PORT = process.env.PORT || 8787;
const ROOM_TTL_MS = 6 * 60 * 60 * 1000;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const rooms = new Map();

function newCode() {
  let code = "";
  for (let i = 0; i < 6; i++) code += ALPHABET[crypto.randomInt(ALPHABET.length)];
  return rooms.has(code) ? newCode() : code;
}

function capacity(format) {
  return { "1v1": 2, "2v2": 4, "team": 2 }[format] || 2;
}

function opposite(side) {
  return side === "Affirmative" ? "Negative" : "Affirmative";
}

function sideFor(room, slot) {
  if (room.format === "team") return room.hostSide;
  return slot % 2 === 0 ? room.hostSide : opposite(room.hostSide);
}

function roleFor(room, slot) {
  if (room.format === "2v2") return slot < 2 ? "First speaker" : "Second speaker";
  if (room.format === "team") return slot === 0 ? "Case" : "Rebuttal";
  return "Debater";
}

const TEAM_SCRIPT = [
  { type: "player", slot: 0, kind: "speech" },
  { type: "ai", kind: "speech" },
  { type: "ai", kind: "crossfireQ" },
  { type: "player", slot: 0, kind: "crossfireA" },
  { type: "player", slot: 1, kind: "crossfireA" },
  { type: "player", slot: 0, kind: "crossfireA" },
  { type: "player", slot: 1, kind: "speech" },
];

function teamStep(n) {
  if (n < TEAM_SCRIPT.length) return TEAM_SCRIPT[n];
  const k = n - TEAM_SCRIPT.length;
  return k % 2 === 0
    ? { type: "ai", kind: "speech" }
    : { type: "player", slot: Math.floor(k / 2) % 2, kind: "speech" };
}

function expected(room) {
  if (room.status !== "live") return null;
  const order = [...room.players].sort((a, b) => a.slot - b.slot);
  const n = room.speeches.length;
  if (room.format === "team") {
    const step = teamStep(n);
    if (step.type === "ai") return { type: "ai", playerId: null, kind: step.kind, questionIndex: null };
    const player = order[step.slot % order.length];
    const answered = room.speeches.filter((s) => s.kind === "crossfireA").length;
    return { type: "player", playerId: player.id, kind: step.kind, questionIndex: step.kind === "crossfireA" ? answered : null };
  }
  return { type: "player", playerId: order[n % order.length].id, kind: "speech", questionIndex: null };
}

function view(room) {
  return { ...room, capacity: capacity(room.format), expected: expected(room) };
}

function send(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(data),
    "Access-Control-Allow-Origin": "*",
  });
  res.end(data);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1e6) reject(new Error("Body too large"));
    });
    req.on("end", () => {
      try { resolve(raw ? JSON.parse(raw) : {}); } catch (e) { reject(e); }
    });
  });
}

function cleanup() {
  const now = Date.now();
  for (const [code, room] of rooms) if (now - room.updatedAt > ROOM_TTL_MS) rooms.delete(code);
}
setInterval(cleanup, 10 * 60 * 1000).unref();

function touch(room) { room.updatedAt = Date.now(); }

function requireHost(room, playerId) {
  if (room.hostId !== playerId) throw Object.assign(new Error("Only the host can do that"), { status: 403 });
}

const PUBLIC = path.join(HERE, "public");
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ttf": "font/ttf",
  ".txt": "text/plain; charset=utf-8",
  ".webmanifest": "application/manifest+json",
};

async function serveStatic(res, pathname) {
  let file = path.normalize(path.join(PUBLIC, decodeURIComponent(pathname)));
  if (!file.startsWith(PUBLIC)) return send(res, 403, { error: "Forbidden" });
  const info = await stat(file).catch(() => null);
  if (!info || info.isDirectory()) file = path.extname(pathname) ? null : path.join(PUBLIC, "index.html");
  if (!file) return send(res, 404, { error: "Not found" });
  const data = await readFile(file).catch(() => null);
  if (!data) return send(res, 404, { error: "Not found" });
  res.writeHead(200, {
    "Content-Type": TYPES[path.extname(file)] || "application/octet-stream",
    "Content-Length": data.length,
    "Cache-Control": "no-cache",
    "X-Content-Type-Options": "nosniff",
  });
  res.end(data);
}

const AI_LIMIT = Number(process.env.AI_RATE_LIMIT || 120);
const AI_WINDOW_MS = 10 * 60 * 1000;
const aiCalls = new Map();

function clientIP(req) {
  const forwarded = process.env.TRUST_PROXY ? String(req.headers["x-forwarded-for"] || "").split(",")[0].trim() : "";
  return forwarded || req.socket.remoteAddress || "unknown";
}

function allowAI(req) {
  const now = Date.now();
  const ip = clientIP(req);
  const recent = (aiCalls.get(ip) || []).filter((t) => now - t < AI_WINDOW_MS);
  if (recent.length >= AI_LIMIT) return false;
  recent.push(now);
  aiCalls.set(ip, recent);
  return true;
}

setInterval(() => {
  const now = Date.now();
  for (const [ip, times] of aiCalls) if (!times.some((t) => now - t < AI_WINDOW_MS)) aiCalls.delete(ip);
}, AI_WINDOW_MS).unref();

const ACCESS_CODE = process.env.ACCESS_CODE || "";

function hasAccess(req) {
  if (!ACCESS_CODE) return true;
  const given = Buffer.from(String(req.headers["x-access-code"] || ""));
  const want = Buffer.from(ACCESS_CODE);
  return given.length === want.length && crypto.timingSafeEqual(given, want);
}

async function handleAPI(req, res, action) {
  if (req.method === "GET" && action === "status") {
    return send(res, 200, { ai: claude.hasKey(), model: claude.model(), locked: Boolean(ACCESS_CODE) });
  }
  if (req.method !== "POST") return send(res, 404, { error: "Not found" });
  if (!allowAI(req)) return send(res, 429, { error: "Too many AI requests from this connection. Wait a few minutes and try again." });
  if (!hasAccess(req)) return send(res, 401, { error: "That access code isn't right." });
  if (action === "unlock") return send(res, 200, { ok: true });

  const b = await readBody(req);
  const config = claude.cleanConfig(b.config);
  const history = claude.cleanHistory(b.history || b.transcript);
  const text = (value, max) => String(value || "").slice(0, max).trim();

  switch (action) {
    case "turn":
      return send(res, 200, { text: await claude.liveTurn(config, history) });
    case "crossfire":
      return send(res, 200, { questions: await claude.crossfireQuestions(config, history) });
    case "statcheck":
      return send(res, 200, { text: await claude.checkStatistics(text(b.text, 8000), text(b.topic, 600), config.language) });
    case "feedback":
      return send(res, 200, { feedback: await claude.postSessionFeedback(config, history) });
    case "judge":
      return send(res, 200, { decision: await claude.judgeRound(config, history) });
    case "inquiry":
      return send(res, 200, { text: await claude.pointOfInquiry(config, text(b.question, 1000), history) });
    case "voice":
      return send(res, 200, { audio: await claude.voice(text(b.text, 1500)) });
    case "statlookup":
      return send(res, 200, { text: await claude.lookUpStatistic(text(b.question, 500), b.committee, config.language) });
    default:
      return send(res, 404, { error: "Not found" });
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const parts = url.pathname.split("/").filter(Boolean);

    if (req.method === "GET" && url.pathname === "/health") return send(res, 200, { ok: true, rooms: rooms.size });

    if (parts[0] === "api") return await handleAPI(req, res, parts[1]);

    if (req.method === "GET" && parts[0] !== "rooms") return await serveStatic(res, url.pathname);

    if (req.method === "POST" && parts[0] === "rooms" && parts.length === 1) {
      const b = await readBody(req);
      const hostId = crypto.randomUUID();
      const room = {
        code: newCode(),
        format: b.format || "1v1",
        topic: b.topic || "",
        language: b.language || "English",
        difficulty: b.difficulty || "Medium",
        judgePreset: b.judgePreset || "Novice",
        judgeInstructions: b.judgeInstructions || "",
        hostId,
        hostSide: b.hostSide === "Negative" ? "Negative" : "Affirmative",
        players: [],
        speeches: [],
        status: "lobby",
        result: null,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      room.players.push({ id: hostId, name: (b.hostName || "Host").slice(0, 40), slot: 0, side: sideFor(room, 0), role: roleFor(room, 0) });
      rooms.set(room.code, room);
      return send(res, 201, { room: view(room), playerId: hostId });
    }

    if (parts[0] !== "rooms" || !parts[1]) return send(res, 404, { error: "Not found" });
    const room = rooms.get(parts[1].toUpperCase());
    if (!room) return send(res, 404, { error: "No room with that code" });
    const action = parts[2];

    if (req.method === "GET" && !action) return send(res, 200, { room: view(room) });

    const b = await readBody(req);

    if (req.method === "POST" && action === "join") {
      if (room.status !== "lobby") return send(res, 409, { error: "That round has already started" });
      if (room.players.length >= capacity(room.format)) return send(res, 409, { error: "That room is full" });
      const slot = room.players.length;
      const player = { id: crypto.randomUUID(), name: (b.name || "Debater").slice(0, 40), slot, side: sideFor(room, slot), role: roleFor(room, slot) };
      room.players.push(player);
      touch(room);
      return send(res, 200, { room: view(room), playerId: player.id });
    }

    if (req.method === "POST" && action === "status") {
      requireHost(room, b.playerId);
      const allowed = ["live", "judging", "done"];
      if (!allowed.includes(b.status)) return send(res, 400, { error: "Bad status" });
      if (b.status === "live" && room.players.length < capacity(room.format)) return send(res, 409, { error: "Waiting for more debaters" });
      room.status = b.status;
      touch(room);
      return send(res, 200, { room: view(room) });
    }

    if (req.method === "POST" && action === "speeches") {
      const exp = expected(room);
      if (!exp || exp.type !== "player" || exp.playerId !== b.playerId) return send(res, 409, { error: "It isn't your turn" });
      const player = room.players.find((p) => p.id === b.playerId);
      const text = String(b.text || "").trim();
      if (!text) return send(res, 400, { error: "Empty speech" });
      room.speeches.push({ id: crypto.randomUUID(), playerId: player.id, speaker: player.name, side: player.side, role: player.role, text, kind: exp.kind || "speech", statCheck: b.statCheck || null });
      touch(room);
      return send(res, 200, { room: view(room) });
    }

    if (req.method === "POST" && action === "ai") {
      requireHost(room, b.playerId);
      const exp = expected(room);
      if (!exp || exp.type !== "ai") return send(res, 409, { error: "Not the AI's turn" });
      const text = String(b.text || "").trim();
      if (!text) return send(res, 400, { error: "Empty speech" });
      room.speeches.push({ id: crypto.randomUUID(), playerId: null, speaker: b.speaker || "Opposing team", side: opposite(room.hostSide), role: "AI", text, kind: exp.kind || "speech", statCheck: null });
      touch(room);
      return send(res, 200, { room: view(room) });
    }

    if (req.method === "POST" && action === "statcheck") {
      const speech = room.speeches.find((s) => s.id === b.speechId && s.playerId === b.playerId);
      if (!speech) return send(res, 404, { error: "No such speech" });
      speech.statCheck = String(b.statCheck || "");
      touch(room);
      return send(res, 200, { room: view(room) });
    }

    if (req.method === "POST" && action === "result") {
      requireHost(room, b.playerId);
      room.result = { decision: b.decision || null, feedback: b.feedback || null };
      room.status = "done";
      touch(room);
      return send(res, 200, { room: view(room) });
    }

    return send(res, 404, { error: "Not found" });
  } catch (e) {
    return send(res, e.status || 500, { error: e.message || "Server error" });
  }
});

server.listen(PORT, () => {
  console.log(`Verbatim is running at http://localhost:${PORT}`);
  if (!claude.hasKey()) console.log("No ANTHROPIC_API_KEY or GEMINI_API_KEY set. Rounds will fail until you add one to server/.env.");
});
