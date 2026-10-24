import { LANGUAGES } from "../data.js";
import { canDictate } from "../speech.js";
import * as store from "../store.js";
import { h, pageHeader, replace, sectionLabel, subtext } from "../ui.js";

export default function settingsView({ app }) {
  const prefs = store.prefs();

  const toggle = (key, title, detail) => {
    const input = h("input", { type: "checkbox", role: "switch" });
    input.checked = prefs[key];
    input.addEventListener("change", () => store.setPref(key, input.checked));
    return h("label", { class: "toggle-row" },
      h("span", { class: "toggle-text" }, h("span", null, title), h("span", { class: "subtext small" }, detail)),
      input);
  };

  const language = h("select", { class: "field", "aria-label": "Language" }, LANGUAGES.map((l) => h("option", { value: l.id }, l.id)));
  language.value = prefs.language;
  language.addEventListener("change", () => store.setPref("language", language.value));

  const aiStatus = h("div", { class: "stack-sm" });
  const renderStatus = () => replace(aiStatus,
    h("div", { class: "kv" }, h("span", null, "Model"), h("code", null, app.ai.model || "—")),
    h("div", { class: "kv" }, h("span", null, "Server API key"), h("span", { class: app.ai.ready ? "ok-text" : "error" }, app.ai.ready ? "Configured" : "Missing")),
    subtext("The Anthropic API key lives on the Verbatim server, never in your browser. To change it, edit ANTHROPIC_API_KEY in server/.env and restart the server.", "small"));
  renderStatus();

  const el = h("div", { class: "page narrow" },
    pageHeader({ title: "Settings" }),
    h("div", { class: "stack-xl" },
      h("section", { class: "stack reveal" },
        sectionLabel("Language"),
        h("div", { class: "card stack-sm" }, language,
          subtext("Every debate, congress round, and piece of feedback is written in this language.", "small"))),
      h("section", { class: "stack reveal" },
        sectionLabel("Support & accessibility"),
        h("div", { class: "card toggles" },
          toggle("lowPressure", "Low-pressure mode", "A short grounding step before each round, a calmer opponent, and shorter replies. Same rigor, less intensity."),
          toggle("plainLanguage", "Plain-language feedback", "Short sentences, everyday words, jargon defined."),
          toggle("readAloud", "Read replies aloud", "Speaks each AI reply automatically. A speaker button is always available on replies and feedback."),
          toggle("showFillerMeter", "Show filler-word meter", "Live presentational-accuracy bar under the composer. Turn off to reduce clutter.")),
        subtext(canDictate
          ? "Tip: press the microphone in the composer to dictate your speech out loud and still get the filler-word score."
          : "Tip: this browser doesn't support dictation. Chrome, Edge, and Safari do, and your device's own dictation works in the composer too.", "small")),
      h("section", { class: "stack reveal" },
        sectionLabel("AI"),
        h("div", { class: "card" }, aiStatus)),
      h("section", { class: "stack reveal" },
        sectionLabel("Account"),
        h("div", { class: "card stack-sm" },
          h("div", { class: "kv" }, h("span", null, "Signed in as"), h("strong", null, app.user.username)),
          subtext("Your account, sessions, and streak are saved in this browser only.", "small"),
          h("button", { type: "button", class: "button secondary", onClick: () => app.logout() }, "Log out")))));

  return { el, title: "Settings", onStatus: renderStatus };
}
