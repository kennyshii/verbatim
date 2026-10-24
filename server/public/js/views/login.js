import * as store from "../store.js";
import { h, icon, replace } from "../ui.js";

export default function loginView({ app }) {
  let tab = "login";
  let busy = false;

  const username = h("input", { type: "text", class: "field", placeholder: "Username", autocomplete: "username", autocapitalize: "none", spellcheck: "false", "aria-label": "Username" });
  const password = h("input", { type: "password", class: "field", placeholder: "Password", autocomplete: "current-password", "aria-label": "Password" });
  const error = h("p", { class: "error", role: "alert" });
  const submit = h("button", { type: "submit", class: "button primary" });
  const segments = h("div", { class: "segmented", role: "tablist" });

  function render() {
    replace(segments, [["login", "Log in"], ["signup", "Sign up"]].map(([id, label]) =>
      h("button", { type: "button", role: "tab", "aria-selected": tab === id ? "true" : "false", class: tab === id ? "selected" : "", onClick: () => { tab = id; error.textContent = ""; render(); } }, label)));
    password.autocomplete = tab === "login" ? "current-password" : "new-password";
    submit.textContent = busy ? "One moment…" : tab === "login" ? "Log in" : "Sign up";
    submit.disabled = busy;
  }

  async function onSubmit(e) {
    e.preventDefault();
    busy = true;
    error.textContent = "";
    render();
    try {
      const user = tab === "login"
        ? await store.login(username.value, password.value)
        : await store.signup(username.value, password.value);
      password.value = "";
      app.setUser(user);
      app.go("/debate");
    } catch (err) {
      error.textContent = err.message;
    }
    busy = false;
    render();
  }

  render();

  const el = h("div", { class: "login" },
    h("form", { class: "login-card", onSubmit },
      h("div", { class: "brand-large" }, h("img", { src: "/img/logo.png", alt: "" }), h("span", null, "Verbatim")),
      h("p", { class: "subtext center" }, "Practice arguing. Get honest feedback."),
      segments, username, password, error, submit,
      h("p", { class: "subtext small center" }, "Your account and progress are saved in this browser.")),
    h("a", { class: "button secondary join-link", href: "#/join" }, icon("hash"), "Join a round with a code"));

  return { el, title: "Log in" };
}
