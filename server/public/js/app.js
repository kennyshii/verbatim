import * as store from "./store.js";
import * as api from "./api.js";
import { stop as stopSpeaking } from "./speech.js";
import { h, icon, logoMark, replace, confirmDialog } from "./ui.js";
import { autoPills, reveal, slidingPill, transition } from "./motion.js";
import loginView from "./views/login.js";
import homeView from "./views/home.js";
import setupView from "./views/setup.js";
import sessionView from "./views/session.js";
import feedbackView from "./views/feedback.js";
import { congressListView, committeeView } from "./views/congress.js";
import { progressView, sessionDetailView } from "./views/progress.js";
import settingsView from "./views/settings.js";
import communityView from "./views/community.js";
import { joinPageView, roomView } from "./views/online.js";

export const app = {
  user: store.currentUser(),
  ai: { ready: true, model: "" },
  pending: { session: null, feedback: null },
  guard: null,
  go(path) {
    location.hash = `#${path}`;
  },
  goHome(tab = "debate") {
    app.guard = null;
    app.go(`/${tab}`);
  },
  setUser(user) {
    app.user = user;
    renderShell();
  },
  logout() {
    store.logout();
    app.user = null;
    app.pending = { session: null, feedback: null };
    app.guard = null;
    app.go("/login");
  },
};

const PUBLIC_ROUTES = new Set(["login", "join", "room"]);

const ROUTES = [
  [/^\/login$/, () => loginView],
  [/^\/debate$/, () => homeView],
  [/^\/debate\/setup$/, () => setupView],
  [/^\/session$/, () => sessionView],
  [/^\/feedback$/, () => feedbackView],
  [/^\/congress$/, () => congressListView],
  [/^\/congress\/([a-z-]+)$/, () => committeeView],
  [/^\/community$/, () => communityView],
  [/^\/progress$/, () => progressView],
  [/^\/progress\/(\d+)$/, () => sessionDetailView],
  [/^\/settings$/, () => settingsView],
  [/^\/join$/, () => joinPageView],
  [/^\/room\/([A-Za-z0-9]+)$/, () => roomView],
];

const TABS = [
  ["debate", "Debate", "debate"],
  ["congress", "Congress", "congress"],
  ["community", "Take 2", "take2"],
  ["progress", "Progress", "chart"],
  ["settings", "Settings", "gear"],
];

const root = document.getElementById("app");
const nav = h("nav", { class: "tabs", "aria-label": "Sections" });
const userArea = h("div", { class: "user-area" });
const navTitle = h("span", { class: "nav-title", "aria-hidden": "true" });
const main = h("main", { id: "view", tabindex: "-1" });
const topbar = h("header", { class: "topbar" },
  h("a", { class: "brand", href: "#/debate", "aria-label": "Verbatim home" },
    logoMark(16),
    h("span", null, "Verbatim")),
  navTitle, userArea);

root.append(topbar, nav, main);
autoPills(main);

const DEPTH = { login: 0, debate: 1, congress: 1, community: 1, progress: 1, settings: 1, join: 2, session: 3, room: 3, feedback: 4 };
const depthOf = (path) => {
  const parts = path.split("/").filter(Boolean);
  return (DEPTH[parts[0]] ?? 1) + (parts.length > 1 && !["session", "room", "feedback"].includes(parts[0]) ? 1 : 0);
};

let titleObserver = null;
function watchTitle(el) {
  titleObserver?.disconnect();
  topbar.classList.remove("titled");
  const heading = el.querySelector(".page-header h1, .home-title h1");
  navTitle.textContent = heading?.textContent || "";
  if (!heading) return;
  titleObserver = new IntersectionObserver(([entry]) => {
    topbar.classList.toggle("titled", !entry.isIntersecting && entry.boundingClientRect.top < 80);
  }, { rootMargin: "-56px 0px 0px 0px" });
  titleObserver.observe(heading);
}

addEventListener("scroll", () => topbar.classList.toggle("scrolled", scrollY > 4), { passive: true });

let current = null;
let currentPath = null;

function parse() {
  const raw = location.hash.replace(/^#/, "") || "/debate";
  const [path, query = ""] = raw.split("?");
  return { path, query: new URLSearchParams(query) };
}

function activeTab(path) {
  const first = path.split("/")[1];
  if (first === "session" || first === "feedback") {
    const config = app.pending.session || app.pending.feedback?.config;
    return config?.kind === "congress" ? "congress" : "debate";
  }
  if (first === "room" || first === "join") return "debate";
  return first;
}

let placePill = null;

function renderShell() {
  const { path } = parse();
  const tab = activeTab(path);
  const loggedIn = Boolean(app.user);
  topbar.classList.toggle("logged-out", !loggedIn);
  const previous = nav.querySelector(".tab.active")?.dataset.tab;
  if (!loggedIn) {
    replace(nav);
  } else if (!nav.querySelector(".tab")) {
    replace(nav, TABS.map(([id, label, iconName]) =>
      h("a", { href: `#/${id}`, "data-tab": id, class: "tab" }, icon(iconName), h("span", null, label))));
    placePill = slidingPill(nav, ".tab.active");
  }
  nav.classList.toggle("hidden", !loggedIn);
  nav.querySelectorAll(".tab").forEach((a) => {
    const on = a.dataset.tab === tab;
    a.classList.toggle("active", on);
    if (on) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current");
  });
  if (placePill && previous !== tab) placePill(Boolean(previous));
  replace(userArea, loggedIn
    ? [h("span", { class: "username" }, app.user.username),
       h("button", { type: "button", class: "link-button", onClick: () => app.logout() }, "Log out")]
    : null);
}

function route() {
  const { path, query } = parse();
  const first = path.split("/")[1];

  if (app.guard && currentPath && path !== currentPath) {
    const target = location.hash;
    const message = app.guard();
    if (message) {
      history.replaceState(null, "", `#${currentPath}`);
      confirmDialog(message, "Leave this round", () => {
        app.guard = null;
        location.hash = target;
      });
      return;
    }
  }

  if (!app.user && !PUBLIC_ROUTES.has(first)) return app.go("/login");
  if (app.user && first === "login") return app.go("/debate");

  const match = ROUTES.find(([pattern]) => pattern.test(path));
  if (!match) return app.go("/debate");

  const from = currentPath ? depthOf(currentPath) : null;
  const to = depthOf(path);
  const direction = from === null ? "none" : to > from ? "forward" : to < from ? "back" : "fade";

  current?.destroy?.();
  stopSpeaking();
  app.guard = null;
  currentPath = path;

  const params = path.match(match[0]).slice(1);
  const swap = () => {
    document.body.classList.remove("focus-mode");
    const view = match[1]()({ params, query, app });
    current = view;
    replace(main, view.el);
    document.title = view.title ? `${view.title} · Verbatim` : "Verbatim";
    renderShell();
    window.scrollTo(0, 0);
    reveal(main);
    watchTitle(main);
    view.mounted?.();
    main.focus({ preventScroll: true });
  };
  if (direction === "none") swap(); else transition(direction, swap);
}

function start() {
  window.addEventListener("hashchange", route);
  window.addEventListener("beforeunload", (e) => {
    if (app.guard?.()) e.preventDefault();
  });
  route();
}

function showGate() {
  const code = h("input", { type: "password", class: "field", placeholder: "Access code", autocomplete: "off", "aria-label": "Access code" });
  const error = h("p", { class: "error", role: "alert" });
  const button = h("button", { type: "submit", class: "button primary" }, "Continue");
  const onSubmit = async (e) => {
    e.preventDefault();
    button.disabled = true;
    error.textContent = "";
    try {
      await api.unlock(code.value.trim());
      start();
    } catch (err) {
      error.textContent = err.message;
      button.disabled = false;
    }
  };
  replace(main, h("div", { class: "login" },
    h("form", { class: "login-card", onSubmit },
      h("div", { class: "brand-large" }, logoMark(30), h("span", null, "Verbatim")),
      code, error, button)));
  renderShell();
  code.focus();
}

api.status().then(async (s) => {
  app.ai = { ready: s.ai, model: s.model };
  if (s.locked) {
    try {
      await api.unlock(api.accessCode());
    } catch {
      return showGate();
    }
  }
  start();
}).catch(() => start());
