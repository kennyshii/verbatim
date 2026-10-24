import { h, icon } from "./ui.js";

export const reduceMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

let revealObserver = null;

function observer() {
  if (revealObserver) return revealObserver;
  revealObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add("in");
      revealObserver.unobserve(entry.target);
    }
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
  return revealObserver;
}

export function reveal(root) {
  const items = root.querySelectorAll(".reveal");
  if (reduceMotion()) {
    items.forEach((el) => el.classList.add("in"));
    return;
  }
  items.forEach((el) => observer().observe(el));
}

const progressItems = new Set();
let ticking = false;

function measure() {
  ticking = false;
  const vh = innerHeight;
  for (const item of progressItems) {
    if (!item.el.isConnected) { progressItems.delete(item); continue; }
    const rect = item.el.getBoundingClientRect();
    const total = rect.height - (item.sticky ? vh : -vh);
    const travelled = item.sticky ? -rect.top : vh - rect.top;
    const p = Math.min(1, Math.max(0, total > 0 ? travelled / total : 0));
    if (p !== item.last) {
      item.last = p;
      item.el.style.setProperty("--p", p.toFixed(4));
      item.onProgress?.(p);
    }
  }
}

function schedule() {
  if (ticking) return;
  ticking = true;
  requestAnimationFrame(measure);
}

addEventListener("scroll", schedule, { passive: true });
addEventListener("resize", schedule);

export function trackProgress(el, { sticky = false, onProgress } = {}) {
  const item = { el, sticky, onProgress, last: -1 };
  if (reduceMotion()) {
    el.style.setProperty("--p", "1");
    onProgress?.(1);
    return () => {};
  }
  progressItems.add(item);
  schedule();
  return () => progressItems.delete(item);
}

export function wordReveal(text, cls = "word-reveal") {
  const words = String(text).split(/(\s+)/);
  const spans = [];
  const el = h("p", { class: cls, "aria-label": text },
    words.map((w) => {
      if (/^\s+$/.test(w)) return w;
      const span = h("span", { class: "w", "aria-hidden": "true" }, w);
      spans.push(span);
      return span;
    }));
  el.update = (p) => {
    const lit = p * (spans.length + 2);
    spans.forEach((s, i) => s.style.setProperty("--o", Math.min(1, Math.max(0.18, lit - i)).toFixed(3)));
  };
  el.update(0);
  return el;
}

export function gallery(cards, { label, cardClass = "" } = {}) {
  const track = h("div", { class: "gallery-track", role: "list", tabindex: "0", "aria-label": label },
    cards.map((card) => h("div", { class: `gallery-item ${cardClass}`, role: "listitem" }, card)));
  const dots = h("div", { class: "dotnav", role: "tablist", "aria-label": `${label} position` });
  const prev = h("button", { type: "button", class: "paddle", "aria-label": "Previous", onClick: () => step(-1) }, icon("back"));
  const next = h("button", { type: "button", class: "paddle", "aria-label": "Next", onClick: () => step(1) }, icon("chevron"));

  const items = () => [...track.children];
  const dotButtons = cards.map((_, i) => h("button", { type: "button", class: "dot", role: "tab", "aria-label": `Item ${i + 1}`, onClick: () => goTo(i) }));
  dots.append(...dotButtons);

  function current() {
    const center = track.scrollLeft + track.clientWidth / 2;
    let best = 0;
    let bestDistance = Infinity;
    items().forEach((item, i) => {
      const mid = item.offsetLeft + item.offsetWidth / 2;
      const d = Math.abs(mid - center);
      if (d < bestDistance) { bestDistance = d; best = i; }
    });
    return best;
  }

  function goTo(i) {
    const item = items()[Math.max(0, Math.min(items().length - 1, i))];
    if (!item) return;
    track.scrollTo({ left: item.offsetLeft - (track.clientWidth - item.offsetWidth) / 2, behavior: reduceMotion() ? "auto" : "smooth" });
  }

  function step(dir) {
    goTo(current() + dir);
  }

  let raf = 0;
  function paint() {
    raf = 0;
    const center = track.scrollLeft + track.clientWidth / 2;
    const active = current();
    items().forEach((item, i) => {
      const mid = item.offsetLeft + item.offsetWidth / 2;
      const d = Math.min(1, Math.abs(mid - center) / (track.clientWidth * 0.75));
      item.style.setProperty("--d", d.toFixed(3));
      item.classList.toggle("active", i === active);
    });
    dotButtons.forEach((dot, i) => {
      dot.classList.toggle("on", i === active);
      dot.setAttribute("aria-selected", i === active ? "true" : "false");
    });
    const max = track.scrollWidth - track.clientWidth - 2;
    prev.disabled = track.scrollLeft <= 2;
    next.disabled = track.scrollLeft >= max;
  }
  const onScroll = () => { if (!raf) raf = requestAnimationFrame(paint); };
  track.addEventListener("scroll", onScroll, { passive: true });
  addEventListener("resize", onScroll);
  track.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") { e.preventDefault(); step(1); }
    if (e.key === "ArrowLeft") { e.preventDefault(); step(-1); }
  });
  requestAnimationFrame(paint);

  return h("div", { class: "gallery" }, track, h("div", { class: "gallery-controls" }, dots, h("div", { class: "paddles" }, prev, next)));
}

export function slidingPill(container, selector = ".selected") {
  const pill = h("span", { class: "pill-indicator", "aria-hidden": "true" });
  container.classList.add("has-pill");
  container.prepend(pill);
  const place = (animate = true) => {
    const target = container.querySelector(selector);
    if (!target) { pill.style.opacity = "0"; return; }
    if (!animate) pill.style.transition = "none";
    pill.style.opacity = "1";
    pill.style.width = `${target.offsetWidth}px`;
    pill.style.height = `${target.offsetHeight}px`;
    pill.style.transform = `translate(${target.offsetLeft}px, ${target.offsetTop}px)`;
    if (!animate) requestAnimationFrame(() => { pill.style.transition = ""; });
  };
  requestAnimationFrame(() => place(false));
  addEventListener("resize", () => place(false));
  return place;
}

const MORPH_SOURCES = ".mode-card, .resolution-card, .line-card, a.nav-row, .feature-tile a.button";
let press = null;
let morphHome = null;

addEventListener("click", (e) => {
  const el = e.target.closest?.("a, button, [role='button']");
  press = el ? { el, at: performance.now() } : null;
}, true);

export function pressedElement() {
  return press && press.el.isConnected && performance.now() - press.at < 800 ? press.el : null;
}

const viewPage = () => document.querySelector("#view > *");
const onScreen = (el) => {
  const r = el.getBoundingClientRect();
  return r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth && r.width > 0;
};

export function transition(direction, update) {
  const pressed = pressedElement();
  const source = pressed?.matches(MORPH_SOURCES) && pressed.getAttribute("href")?.startsWith("#/") ? pressed : null;
  press = null;
  if (!document.startViewTransition || reduceMotion()) {
    morphHome = null;
    return update();
  }
  const root = document.documentElement;
  const returning = !source && direction === "back" ? morphHome : null;
  const named = [];
  const shown = [];
  const fromY = scrollY;
  const name = (el) => { if (el) { el.style.viewTransitionName = "morph"; named.push(el); } };
  if (source) name(source);
  else if (returning) name(viewPage());
  root.dataset.nav = source ? "morph" : returning ? "unmorph" : direction;
  morphHome = null;
  const t = document.startViewTransition(() => {
    named.forEach((el) => { el.style.viewTransitionName = ""; });
    update();
    if (source) {
      name(viewPage());
      morphHome = { href: source.getAttribute("href"), y: fromY };
    } else if (returning) {
      scrollTo(0, returning.y);
      const target = [...document.querySelectorAll(MORPH_SOURCES)].find((el) => el.getAttribute("href") === returning.href);
      const shell = target?.closest(".reveal");
      if (shell) {
        shell.style.transition = "none";
        shell.classList.add("in");
        shown.push(shell);
      }
      if (target && onScreen(target)) name(target);
    }
  });
  t.finished.finally(() => {
    delete root.dataset.nav;
    named.forEach((el) => { el.style.viewTransitionName = ""; });
    shown.forEach((el) => { el.style.transition = ""; });
  });
  return t;
}

export function morphDialog(dialog, origin) {
  if (!origin || !origin.isConnected || reduceMotion()) return null;
  const from = origin.getBoundingClientRect();
  if (!from.width || !from.height) return null;
  const to = dialog.getBoundingClientRect();
  const originStyle = getComputedStyle(origin);
  const dialogStyle = getComputedStyle(dialog);
  const dx = from.left + from.width / 2 - (to.left + to.width / 2);
  const dy = from.top + from.height / 2 - (to.top + to.height / 2);
  const insetY = Math.max(0, (to.height - from.height) / 2);
  const insetX = Math.max(0, (to.width - from.width) / 2);
  const startRadius = Math.min(parseFloat(originStyle.borderTopLeftRadius) || 14, from.height / 2, from.width / 2);
  const startBg = originStyle.backgroundColor === "rgba(0, 0, 0, 0)" ? dialogStyle.backgroundColor : originStyle.backgroundColor;
  const shape = [
    { transform: `translate(${dx}px, ${dy}px)`, clipPath: `inset(${insetY}px ${insetX}px round ${startRadius}px)`, backgroundColor: startBg },
    { transform: "none", clipPath: `inset(0px 0px round ${dialogStyle.borderRadius})`, backgroundColor: dialogStyle.backgroundColor },
  ];
  const parts = [...dialog.children];
  const play = (closing) => {
    const order = (frames) => (closing ? [...frames].reverse() : frames);
    const easing = closing ? "cubic-bezier(0.4, 0, 0.2, 1)" : "cubic-bezier(0.16, 1, 0.3, 1)";
    const fill = closing ? "forwards" : "none";
    const body = dialog.animate(order(shape), { duration: closing ? 360 : 520, easing, fill });
    dialog.animate({ opacity: order([0, 1]) }, { duration: closing ? 300 : 360, easing, fill, pseudoElement: "::backdrop" });
    parts.forEach((p) => p.animate({ opacity: order([0, 1]), transform: order(["translateY(8px)", "none"]) },
      { duration: closing ? 140 : 320, delay: closing ? 0 : 140, easing, fill: closing ? "forwards" : "backwards" }));
    return body.finished;
  };
  play(false);
  return () => (origin.isConnected && onScreen(origin) ? play(true) : Promise.resolve());
}

const lastPill = new Map();

function pillKey(group) {
  return [...group.querySelectorAll(":scope > button, :scope > .chip")].map((b) => b.textContent.trim()).join("|");
}

function attachPill(group) {
  let pill = group.querySelector(":scope > .pill-indicator");
  if (!pill) {
    pill = h("span", { class: "pill-indicator", "aria-hidden": "true" });
    group.classList.add("has-pill");
    group.prepend(pill);
  }
  const target = group.querySelector(":scope > .selected");
  if (!target) { pill.style.opacity = "0"; return; }
  const key = pillKey(group);
  const to = { x: target.offsetLeft, y: target.offsetTop, w: target.offsetWidth, h: target.offsetHeight };
  const from = lastPill.get(key);
  const apply = (r) => {
    pill.style.width = `${r.w}px`;
    pill.style.height = `${r.h}px`;
    pill.style.transform = `translate(${r.x}px, ${r.y}px)`;
  };
  const moved = !from || from.x !== to.x || from.y !== to.y || from.w !== to.w;
  if (from && moved && !reduceMotion()) {
    pill.style.transition = "none";
    apply(from);
    pill.getBoundingClientRect();
    pill.style.transition = "";
  }
  pill.style.opacity = "1";
  apply(to);
  lastPill.set(key, to);
}

export function autoPills(root) {
  let queued = false;
  const scan = () => {
    queued = false;
    root.querySelectorAll(".chips:not(.wrap), .segmented").forEach(attachPill);
  };
  const queue = () => { if (!queued) { queued = true; requestAnimationFrame(scan); } };
  new MutationObserver(queue).observe(root, { childList: true, subtree: true });
  addEventListener("resize", queue);
  queue();
}
