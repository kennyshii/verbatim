import * as store from "./store.js";
import * as api from "./api.js";
import { stop as stopSpeaking } from "./speech.js";
import { h, icon, replace, confirmDialog } from "./ui.js";
import loginView from "./views/login.js";
import homeView from "./views/home.js";
import setupView from "./views/setup.js";
import sessionView from "./views/session.js";
import feedbackView from "./views/feedback.js";
import { congressListView, committeeView } from "./views/congress.js";
import { progressView, sessionDetailView } from "./views/progress.js";
import settingsView from "./views/settings.js";
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
  [/^\/progress$/, () => progressView],
  [/^\/progress\/(\d+)$/, () => sessionDetailView],
  [/^\/settings$/, () => settingsView],
  [/^\/join$/, () => joinPageView],
  [/^\/room\/([A-Za-z0-9]+)$/, () => roomView],
];

const TABS = [
  ["debate", "Debate", "debate"],
  ["congress", "Congress", "congress"],
  ["progress", "Progress", "chart"],
  ["settings", "Settings", "gear"],
];

const root = document.getElementById("app");
const nav = h("nav", { class: "tabs", "aria-label": "Sections" });
const userArea = h("div", { class: "user-area" });
const main = h("main", { id: "view", tabindex: "-1" });
const topbar = h("header", { class: "topbar" },
  h("a", { class: "brand", href: "#/debate", "aria-label": "Verbatim home" },
    h("img", { src: "/img/logo.png", alt: "", width: "44", height: "23" }),
    h("span", null, "Verbatim")),
  nav, userArea);

root.append(topbar, main);

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

function renderShell() {
  const { path } = parse();
  const tab = activeTab(path);
  const loggedIn = Boolean(app.user);
  topbar.classList.toggle("logged-out", !loggedIn);
  replace(nav, loggedIn ? TABS.map(([id, label, iconName]) =>
    h("a", { href: `#/${id}`, class: `tab${tab === id ? " active" : ""}`, "aria-current": tab === id ? "page" : null },
      icon(iconName), h("span", null, label))) : null);
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

  current?.destroy?.();
  stopSpeaking();
  app.guard = null;
  currentPath = path;
  document.body.classList.remove("focus-mode");

  const params = path.match(match[0]).slice(1);
  const view = match[1]()({ params, query, app });
  current = view;
  replace(main, view.el);
  document.title = view.title ? `${view.title} · Verbatim` : "Verbatim";
  renderShell();
  window.scrollTo(0, 0);
  main.focus({ preventScroll: true });
}

window.addEventListener("hashchange", route);
window.addEventListener("beforeunload", (e) => {
  if (app.guard?.()) e.preventDefault();
});

api.status().then((s) => {
  app.ai = { ready: s.ai, model: s.model };
  current?.onStatus?.();
}).catch(() => {});

route();
