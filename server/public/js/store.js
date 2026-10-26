const KEYS = {
  users: "verbatim.users",
  sessions: "verbatim.sessions",
  streaks: "verbatim.streaks",
  current: "verbatim.currentUser",
  prefs: "verbatim.prefs",
  community: "verbatim.community",
  notes: "verbatim.notes",
};

function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    throw new Error("This browser won't let Verbatim save data. Turn off private browsing or allow site data and try again.");
  }
}

export const DEFAULT_PREFS = { language: "English", lowPressure: false, readAloud: false, plainLanguage: false, showFillerMeter: true };

export const prefs = () => ({ ...DEFAULT_PREFS, ...read(KEYS.prefs, {}) });
export const setPref = (key, value) => write(KEYS.prefs, { ...prefs(), [key]: value });

const ITERATIONS = 120_000;
const b64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
const unb64 = (text) => Uint8Array.from(atob(text), (c) => c.charCodeAt(0));

function requireCrypto() {
  if (!globalThis.crypto?.subtle) throw new Error("Accounts need a secure connection. Open Verbatim over https or at localhost.");
}

async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256));
}

async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return `pbkdf2$${ITERATIONS}$${b64(salt)}$${b64(await pbkdf2(password, salt, ITERATIONS))}`;
}

async function verifyPassword(password, stored) {
  const [scheme, rounds, salt, expected] = String(stored).split("$");
  if (scheme !== "pbkdf2" || !rounds || !salt || !expected) return false;
  const derived = await pbkdf2(password, unb64(salt), Number(rounds));
  const want = unb64(expected);
  if (want.length !== derived.length) return false;
  let diff = 0;
  for (let i = 0; i < want.length; i++) diff |= want[i] ^ derived[i];
  return diff === 0;
}

const publicUser = (u) => ({ id: u.id, username: u.username, createdAt: u.createdAt });
const findUser = (name) => read(KEYS.users, []).find((u) => u.username.toLowerCase() === name.toLowerCase());

export async function signup(username, password) {
  const name = username.trim();
  if (!name || !password) throw new Error("Enter a username and password.");
  requireCrypto();
  if (findUser(name)) throw new Error("That username is already taken.");
  const users = read(KEYS.users, []);
  const user = { id: users.reduce((max, u) => Math.max(max, u.id), 0) + 1, username: name, passwordHash: await hashPassword(password), createdAt: new Date().toISOString() };
  write(KEYS.users, [...users, user]);
  write(KEYS.current, user.id);
  return publicUser(user);
}

export async function login(username, password) {
  const name = username.trim();
  if (!name || !password) throw new Error("Enter a username and password.");
  requireCrypto();
  const user = findUser(name);
  if (!user) throw new Error("No account with that username in this browser. Choose Sign up to create one.");
  if (!(await verifyPassword(password, user.passwordHash))) throw new Error("That password doesn't match this account.");
  write(KEYS.current, user.id);
  return publicUser(user);
}

export function currentUser() {
  const id = read(KEYS.current, null);
  const user = read(KEYS.users, []).find((u) => u.id === id);
  return user ? publicUser(user) : null;
}

export function logout() {
  try { localStorage.removeItem(KEYS.current); } catch {}
}

export function saveSession(userId, config, transcript, feedback) {
  const all = read(KEYS.sessions, []);
  const record = {
    id: all.reduce((max, s) => Math.max(max, s.id), 0) + 1,
    userId,
    kind: config.kind,
    topic: config.topic,
    committee: config.committee || "",
    language: config.language,
    difficulty: config.difficulty,
    mode: config.mode,
    participants: config.participants || [],
    transcript,
    feedback,
    createdAt: new Date().toISOString(),
  };
  write(KEYS.sessions, [...all, record]);
  updateStreak(userId);
  return record;
}

export function updateSessionFeedback(id, feedback) {
  write(KEYS.sessions, read(KEYS.sessions, []).map((s) => (s.id === id ? { ...s, feedback } : s)));
}

export const sessionsFor = (userId) => read(KEYS.sessions, []).filter((s) => s.userId === userId).sort((a, b) => b.id - a.id);
export const sessionById = (userId, id) => sessionsFor(userId).find((s) => s.id === id);

function dayString(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function yesterday() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return d;
}

export function streak(userId) {
  const stored = read(KEYS.streaks, {})[userId] || { current: 0, longest: 0, lastActiveDate: null };
  const alive = stored.lastActiveDate === dayString(new Date()) || stored.lastActiveDate === dayString(yesterday());
  return alive ? stored : { ...stored, current: 0 };
}

function updateStreak(userId) {
  const today = dayString(new Date());
  const existing = streak(userId);
  if (existing.lastActiveDate === today) return;
  const current = existing.lastActiveDate === dayString(yesterday()) ? existing.current + 1 : 1;
  const all = read(KEYS.streaks, {});
  all[userId] = { current, longest: Math.max(existing.longest, current), lastActiveDate: today };
  write(KEYS.streaks, all);
}

export const notes = (userId) => read(KEYS.notes, {})[userId] || "";
export const saveNotes = (userId, text) => write(KEYS.notes, { ...read(KEYS.notes, {}), [userId]: text });

export const communityPosts = () => read(KEYS.community, null);
export const saveCommunityPosts = (posts) => write(KEYS.community, posts);
