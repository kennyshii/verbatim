import { LANGUAGES } from "../data.js";
import * as store from "../store.js";
import { h, pageHeader, replace, sectionLabel } from "../ui.js";

export default function settingsView({ app }) {
  const prefs = store.prefs();

  const toggle = (key, title) => {
    const input = h("input", { type: "checkbox", role: "switch" });
    input.checked = prefs[key];
    input.addEventListener("change", () => store.setPref(key, input.checked));
    return h("label", { class: "toggle-row" },
      h("span", { class: "toggle-text" }, h("span", null, title)),
      input);
  };

  const language = h("select", { class: "field", "aria-label": "Language" }, LANGUAGES.map((l) => h("option", { value: l.id }, l.id)));
  language.value = prefs.language;
  language.addEventListener("change", () => store.setPref("language", language.value));

  const aiStatus = h("div", { class: "stack-sm" });
  const renderStatus = () => replace(aiStatus,
    h("div", { class: "kv" }, h("span", null, "Model"), h("code", null, app.ai.model || "—")),
    h("div", { class: "kv" }, h("span", null, "Server API key"), h("span", { class: app.ai.ready ? "ok-text" : "error" }, app.ai.ready ? "Configured" : "Missing")));
  renderStatus();

  const el = h("div", { class: "page narrow" },
    pageHeader({ title: "Settings" }),
    h("div", { class: "stack-xl" },
      h("section", { class: "stack reveal" },
        sectionLabel("Language"),
        h("div", { class: "card stack-sm" }, language)),
      h("section", { class: "stack reveal" },
        sectionLabel("Support & accessibility"),
        h("div", { class: "card toggles" },
          toggle("lowPressure", "Low-pressure mode"),
          toggle("plainLanguage", "Plain-language feedback"),
          toggle("readAloud", "Read replies aloud"),
          toggle("showFillerMeter", "Show filler-word meter"))),
      h("section", { class: "stack reveal" },
        sectionLabel("AI"),
        h("div", { class: "card" }, aiStatus)),
      h("section", { class: "stack reveal" },
        sectionLabel("Account"),
        h("div", { class: "card stack-sm" },
          h("div", { class: "kv" }, h("span", null, "Signed in as"), h("strong", null, app.user.username)),
          h("button", { type: "button", class: "button secondary", onClick: () => app.logout() }, "Log out")))));

  return { el, title: "Settings", onStatus: renderStatus };
}
