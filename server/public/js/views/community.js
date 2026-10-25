import { FEATURED_RESOLUTION, SUGGESTED_RESOLUTIONS } from "../data.js";
import { reveal } from "../motion.js";
import * as store from "../store.js";
import { autoGrow, confirmDialog, h, icon, maskWords, replace } from "../ui.js";

const CLIP_SECONDS = 4;
const BARS = 36;
const TOPICS = [FEATURED_RESOLUTION.text, ...SUGGESTED_RESOLUTIONS];
const shortTopic = (t) => t.replace(/^Resolved:\s*/, "");

const minutesAgo = (m) => new Date(Date.now() - m * 60000).toISOString();

function seedPosts() {
  const post = (id, author, event, topic, text, age, likes, comments = []) => ({
    id, author, event, topic, text, at: minutesAgo(age), likes, likedBy: [], audio: null, peaks: null,
    comments: comments.map(([who, body, m], i) => ({ id: `${id}c${i}`, author: who, text: body, at: minutesAgo(m) })),
  });
  return [
    post("s1", "Priya Natarajan", "Lincoln-Douglas · Varsity", FEATURED_RESOLUTION.text,
      "A job that can't cover rent isn't economic security. It's a treadmill.", 38, 24,
      [["Marcus Bell", "“Treadmill” is such a good image. Stealing that for my 1AR.", 21], ["Elena Ruiz", "Try a half-second pause before “treadmill.” Let it land.", 12]]),
    post("s2", "Marcus Bell", "Public Forum · JV", SUGGESTED_RESOLUTIONS[1],
      "Data centers drink a town's water before the town does.", 130, 17,
      [["Jordan Kim", "Have the gallons ready. Judges will ask for the number.", 64]]),
    post("s3", "Elena Ruiz", "Model Congress · Senate", "A Bill to Repeal Outdated Authorizations for the Use of Military Force",
      "A war vote from 2002 shouldn't still be deciding wars today.", 310, 31,
      [["Priya Natarajan", "Clean. Open your authorship speech with this.", 280]]),
    post("s4", "Jordan Kim", "Lincoln-Douglas · Novice", SUGGESTED_RESOLUTIONS[3],
      "Rivers already have defenders. Rights just give them a seat in court.", 1500, 12),
    post("s5", "Sam Okafor", "Lincoln-Douglas · Varsity", SUGGESTED_RESOLUTIONS[0],
      "The satellites that predict famine came from space research.", 2900, 9),
  ];
}

function load() {
  const saved = store.communityPosts();
  if (saved) return saved;
  const seeded = seedPosts();
  try { store.saveCommunityPosts(seeded); } catch {}
  return seeded;
}

function ago(iso) {
  const m = Math.round((Date.now() - Date.parse(iso)) / 60000);
  if (m < 1) return "Just now";
  if (m < 60) return `${m}m`;
  const hours = Math.round(m / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.round(hours / 24)}d`;
}

const hash = (text) => [...text].reduce((a, c) => (a * 31 + c.charCodeAt(0)) >>> 0, 7);

function avatar(name, size = "") {
  const initials = name.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
  return h("span", { class: `avatar ${size}`, style: { "--hue": hash(name) % 360 }, "aria-hidden": "true" }, initials);
}

function fakePeaks(seed) {
  let x = hash(seed);
  return Array.from({ length: BARS }, (_, i) => {
    x = (x * 1103515245 + 12345) >>> 0;
    const envelope = Math.sin(Math.PI * (i + 0.5) / BARS) ** 0.6;
    return Math.round((0.25 + 0.75 * envelope * ((x % 1000) / 1000 * 0.7 + 0.3)) * 100) / 100;
  });
}

async function measurePeaks(blob) {
  try {
    const context = new (window.AudioContext || window.webkitAudioContext)();
    const buffer = await context.decodeAudioData(await blob.arrayBuffer());
    context.close();
    const data = buffer.getChannelData(0);
    const size = Math.floor(data.length / BARS);
    const raw = Array.from({ length: BARS }, (_, i) => {
      let peak = 0;
      for (let j = i * size; j < (i + 1) * size; j += 16) peak = Math.max(peak, Math.abs(data[j]));
      return peak;
    });
    const max = Math.max(...raw, 0.01);
    return raw.map((p) => Math.round(Math.max(0.12, p / max) * 100) / 100);
  } catch {
    return fakePeaks(String(blob.size));
  }
}

const toDataURL = (blob) => new Promise((resolve, reject) => {
  const reader = new FileReader();
  reader.onload = () => resolve(reader.result);
  reader.onerror = reject;
  reader.readAsDataURL(blob);
});

let stopActive = null;

function player(clip) {
  const peaks = clip.peaks || fakePeaks(clip.id || clip.text);
  const bars = peaks.map((p) => h("i", { style: { "--h": p } }));
  const wave = h("div", { class: "wave", "aria-hidden": "true" }, bars);
  const time = h("span", { class: "clip-time" }, `0:0${CLIP_SECONDS}`);
  const button = h("button", { type: "button", class: "play-button", "aria-label": "Play take" }, icon("play"));
  let frame = 0;
  let audio = null;

  const paint = (p) => {
    const lit = Math.round(p * bars.length);
    bars.forEach((b, i) => b.classList.toggle("on", i < lit));
    time.textContent = `0:0${Math.max(0, Math.ceil(CLIP_SECONDS * (1 - p)))}`;
  };

  const stop = () => {
    cancelAnimationFrame(frame);
    if (audio) { audio.pause(); audio = null; }
    if (!clip.audio && "speechSynthesis" in window) speechSynthesis.cancel();
    replace(button, icon("play"));
    button.setAttribute("aria-label", "Play take");
    paint(0);
    if (stopActive === stop) stopActive = null;
  };

  const run = (progress) => {
    const tick = () => {
      const p = progress();
      paint(Math.min(1, p));
      if (p >= 1) return stop();
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
  };

  const play = () => {
    stopActive?.();
    stopActive = stop;
    replace(button, icon("pause"));
    button.setAttribute("aria-label", "Stop take");
    if (clip.audio) {
      audio = new Audio(clip.audio);
      audio.addEventListener("ended", stop);
      audio.play().catch(stop);
      run(() => (audio ? audio.currentTime / CLIP_SECONDS : 1));
    } else {
      const start = performance.now();
      let done = false;
      if ("speechSynthesis" in window) {
        speechSynthesis.cancel();
        const u = new SpeechSynthesisUtterance(clip.text);
        u.rate = 1.05;
        u.onend = () => { done = true; };
        speechSynthesis.speak(u);
      }
      run(() => (done ? 1 : Math.min(0.97, (performance.now() - start) / (CLIP_SECONDS * 1000))));
    }
  };

  button.addEventListener("click", () => (stopActive === stop ? stop() : play()));
  return { el: h("div", { class: "clip" }, button, wave, time), stop };
}

function recorder(onChange) {
  const ringSvg = '<svg viewBox="0 0 64 64" aria-hidden="true"><circle class="rec-track" cx="32" cy="32" r="29"/><circle class="rec-arc" cx="32" cy="32" r="29" pathLength="100"/></svg>';
  const button = h("button", { type: "button", class: "rec-button", "aria-label": `Record ${CLIP_SECONDS} seconds` });
  const status = h("span", { class: "rec-status" });
  const preview = h("div", { class: "rec-preview" });
  const el = h("div", { class: "recorder" }, button, h("div", { class: "rec-side" }, status, preview));
  let state = "idle";
  let clip = null;
  let media = null;
  let countdown = 0;
  let timer = 0;
  let previewPlayer = null;

  function render() {
    el.dataset.state = state;
    button.innerHTML = ringSvg;
    button.append(h("span", { class: "rec-core" }, state === "recording" ? icon("stop") : state === "done" ? icon("redo") : icon("mic")));
    button.setAttribute("aria-label", state === "recording" ? "Stop recording" : state === "done" ? "Record again" : `Record ${CLIP_SECONDS} seconds`);
    previewPlayer?.stop();
    previewPlayer = null;
    if (state === "done") {
      previewPlayer = player({ ...clip, id: "preview" });
      replace(preview, previewPlayer.el);
    } else replace(preview);
    status.textContent = {
      idle: `Tap to record a ${CLIP_SECONDS}-second take`,
      asking: "Allow microphone access to record…",
      recording: `Recording… ${countdown}`,
      done: "Your take is ready",
      denied: "Microphone blocked. Allow it in your browser's site settings, then try again.",
      unsupported: "This browser can't record audio. Try Chrome, Edge, or Safari.",
    }[state];
  }

  async function start() {
    if (!navigator.mediaDevices?.getUserMedia || !window.MediaRecorder) { state = "unsupported"; return render(); }
    state = "asking";
    render();
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      state = "denied";
      return render();
    }
    const chunks = [];
    media = new MediaRecorder(stream);
    media.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
    media.onstop = async () => {
      stream.getTracks().forEach((t) => t.stop());
      clearInterval(timer);
      const blob = new Blob(chunks, { type: media.mimeType });
      media = null;
      clip = { audio: await toDataURL(blob), peaks: await measurePeaks(blob) };
      state = "done";
      render();
      onChange();
    };
    countdown = CLIP_SECONDS;
    timer = setInterval(() => {
      countdown -= 1;
      if (countdown <= 0) {
        clearInterval(timer);
        if (media?.state === "recording") media.stop();
      } else status.textContent = `Recording… ${countdown}`;
    }, 1000);
    state = "recording";
    media.start();
    render();
  }

  button.addEventListener("click", () => {
    if (state === "recording") { media?.stop(); return; }
    if (state === "asking") return;
    clip = null;
    onChange();
    start();
  });
  render();

  return {
    el,
    clip: () => clip,
    reset: () => { clip = null; state = "idle"; render(); },
    stop: () => { previewPlayer?.stop(); if (media?.state === "recording") media.stop(); },
  };
}

export default function communityView({ app }) {
  const me = app.user.username;
  let posts = load();
  let filter = null;
  let replyTo = null;
  const players = [];

  const persist = () => {
    try {
      store.saveCommunityPosts(posts);
      return true;
    } catch (e) {
      error.textContent = e.message;
      return false;
    }
  };

  const caption = h("textarea", { class: "field post-input", rows: "2", placeholder: `What argument are you citing, ${me}?`, "aria-label": "The argument you're citing" });
  const fit = autoGrow(caption, 160);
  const topic = h("select", { class: "field post-topic", "aria-label": "Resolution" },
    TOPICS.map((t) => h("option", { value: t }, shortTopic(t))));
  const replyNote = h("div");
  const error = h("p", { class: "error", role: "alert" });
  const postButton = h("button", { type: "button", class: "button primary compact", disabled: true, onClick: publish }, "Post take");
  const rec = recorder(sync);

  function sync() {
    fit();
    postButton.disabled = !caption.value.trim() || !rec.clip();
  }
  caption.addEventListener("input", sync);

  function renderReply() {
    replace(replyNote, replyTo ? h("div", { class: "reply-note" }, icon("take2"),
      h("span", null, "Responding to ", h("strong", null, replyTo.author)),
      h("button", { type: "button", class: "icon-button small", "aria-label": "Cancel response", onClick: () => { replyTo = null; renderReply(); } }, icon("close"))) : null);
  }

  function publish() {
    const clip = rec.clip();
    const text = caption.value.trim();
    if (!clip || !text) return;
    const post = {
      id: `p${Date.now().toString(36)}`, author: me, event: "Verbatim", topic: topic.value, text, at: new Date().toISOString(),
      likes: 0, likedBy: [], comments: [], audio: clip.audio, peaks: clip.peaks,
      replyTo: replyTo ? { author: replyTo.author, text: replyTo.text } : null,
    };
    posts = [post, ...posts];
    if (!persist()) { posts = posts.slice(1); return; }
    error.textContent = "";
    caption.value = "";
    replyTo = null;
    renderReply();
    rec.reset();
    filter = null;
    sync();
    render();
  }

  const composerCard = h("section", { class: "card post-composer" },
    h("div", { class: "post-composer-head" }, avatar(me), caption),
    replyNote,
    rec.el,
    h("div", { class: "post-composer-foot" }, topic, postButton),
    error);

  function respond(post) {
    replyTo = post;
    if (TOPICS.includes(post.topic)) topic.value = post.topic;
    renderReply();
    composerCard.scrollIntoView({ behavior: "smooth", block: "center" });
    caption.focus({ preventScroll: true });
  }

  function toggleLike(post) {
    post.likedBy = post.likedBy.includes(me) ? post.likedBy.filter((n) => n !== me) : [...post.likedBy, me];
    persist();
  }

  function postCard(post) {
    const clip = player(post);
    players.push(clip);
    const liked = post.likedBy.includes(me);
    const comments = h("div", { class: "comments" });
    const input = h("input", { type: "text", class: "field comment-input", placeholder: "Write a comment…", "aria-label": "Write a comment" });
    const likeButton = h("button", { type: "button", class: `post-action${liked ? " liked" : ""}`, "aria-pressed": liked ? "true" : "false" }, icon("heart"), "Like");
    const counts = h("div", { class: "post-counts" });

    const renderCounts = () => {
      const n = post.likes + post.likedBy.length;
      replace(counts,
        n ? h("span", null, h("span", { class: "like-dot" }, icon("heart")), String(n)) : h("span"),
        post.comments.length ? h("span", null, `${post.comments.length} comment${post.comments.length === 1 ? "" : "s"}`) : null);
    };
    const renderComments = () => replace(comments, post.comments.map((c) => h("div", { class: "comment" },
      avatar(c.author, "small"),
      h("div", null,
        h("div", { class: "comment-bubble" }, h("strong", null, c.author), h("span", null, c.text)),
        h("span", { class: "comment-time" }, ago(c.at))))));

    likeButton.addEventListener("click", () => {
      toggleLike(post);
      const on = post.likedBy.includes(me);
      likeButton.classList.toggle("liked", on);
      likeButton.setAttribute("aria-pressed", on ? "true" : "false");
      renderCounts();
    });
    input.addEventListener("keydown", (e) => {
      if (e.key !== "Enter" || !input.value.trim()) return;
      post.comments = [...post.comments, { id: `c${Date.now().toString(36)}`, author: me, text: input.value.trim(), at: new Date().toISOString() }];
      if (!persist()) return;
      input.value = "";
      renderComments();
      renderCounts();
    });
    renderCounts();
    renderComments();

    return h("article", { class: "card post reveal" },
      h("header", { class: "post-head" },
        avatar(post.author),
        h("div", { class: "post-who" },
          h("strong", null, post.author),
          h("span", { class: "subtext small" }, `${post.event} · ${ago(post.at)}`)),
        post.author === me ? h("button", { type: "button", class: "icon-button small", "aria-label": "Delete take", onClick: () => confirmDialog("Delete this take?", "Delete", () => {
          posts = posts.filter((p) => p !== post);
          persist();
          render();
        }) }, icon("close")) : null),
      h("button", { type: "button", class: "post-topic-tag", onClick: () => { filter = post.topic; render(); } }, shortTopic(post.topic)),
      post.replyTo ? h("div", { class: "post-reply" }, icon("take2"), h("span", null, "Take 2 on ", h("strong", null, post.replyTo.author), ": “", post.replyTo.text, "”")) : null,
      h("p", { class: "post-text" }, `“${post.text}”`),
      clip.el,
      counts,
      h("div", { class: "post-actions" },
        likeButton,
        h("button", { type: "button", class: "post-action", onClick: () => input.focus() }, icon("comment"), "Comment"),
        h("button", { type: "button", class: "post-action", onClick: () => respond(post) }, icon("take2"), "Take 2")),
      comments,
      h("div", { class: "comment-row" }, avatar(me, "small"), input));
  }

  const feed = h("div", { class: "feed-list" });
  const trending = h("div", { class: "stack-sm" });

  function render() {
    players.splice(0).forEach((p) => p.stop());
    const shown = filter ? posts.filter((p) => p.topic === filter) : posts;
    replace(feed,
      filter ? h("div", { class: "filter-note" }, h("span", null, "Takes on ", h("strong", null, shortTopic(filter))),
        h("button", { type: "button", class: "link-button", onClick: () => { filter = null; render(); } }, "Show all")) : null,
      shown.length ? shown.map(postCard) : h("div", { class: "card empty" }, "No takes on this resolution yet. Be the first."));
    const counts = new Map();
    posts.forEach((p) => counts.set(p.topic, (counts.get(p.topic) || 0) + 1));
    replace(trending, [...counts].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([t, n]) =>
      h("button", { type: "button", class: `trend${filter === t ? " active" : ""}`, onClick: () => { filter = filter === t ? null : t; render(); } },
        h("span", { class: "trend-topic" }, shortTopic(t)),
        h("span", { class: "subtext small" }, `${n} take${n === 1 ? "" : "s"}`))));
    reveal(feed);
  }
  render();

  const el = h("div", { class: "page community" },
    h("header", { class: "hero compact-hero" },
      h("h1", { class: "words reveal" }, maskWords("Take 2.")),
      h("p", { class: "lede reveal", style: { "--i": 1 } }, "Four seconds, one argument. Post your best line out loud and hear how other debaters say theirs.")),
    h("div", { class: "feed-layout" },
      h("div", { class: "feed" }, composerCard, feed),
      h("aside", { class: "feed-side" },
        h("section", { class: "card stack-sm" },
          h("span", { class: "eyebrow" }, "Trending resolutions"),
          trending),
        h("section", { class: "card stack-sm" },
          h("span", { class: "eyebrow" }, "How Take 2 works"),
          h("ol", { class: "how-list" },
            h("li", null, "Type the argument you're citing."),
            h("li", null, `Record a ${CLIP_SECONDS}-second take. It stops on its own.`),
            h("li", null, "Hit Take 2 on any post to answer it with your own."))))));

  return {
    el,
    title: "Take 2",
    destroy() {
      players.forEach((p) => p.stop());
      rec.stop();
    },
  };
}
