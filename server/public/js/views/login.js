import * as store from "../store.js";
import { trackProgress, wordReveal } from "../motion.js";
import { h, icon, logoMark, maskWords, replace } from "../ui.js";

export default function loginView({ app }) {
  let tab = "signup";
  let busy = false;

  const username = h("input", { type: "text", class: "field", placeholder: "Username", autocomplete: "username", autocapitalize: "none", spellcheck: "false", "aria-label": "Username" });
  const password = h("input", { type: "password", class: "field", placeholder: "Password", autocomplete: "new-password", "aria-label": "Password" });
  const error = h("p", { class: "error", role: "alert" });
  const submit = h("button", { type: "submit", class: "button primary" });
  const segments = h("div", { class: "segmented", role: "tablist" });

  function render() {
    replace(segments, [["signup", "Create account"], ["login", "Sign in"]].map(([id, label]) =>
      h("button", { type: "button", role: "tab", "aria-selected": tab === id ? "true" : "false", class: tab === id ? "selected" : "", onClick: () => { tab = id; error.textContent = ""; render(); } }, label)));
    password.autocomplete = tab === "login" ? "current-password" : "new-password";
    submit.textContent = busy ? "One moment…" : tab === "login" ? "Sign in" : "Create account";
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

  const signin = h("section", { class: "signin", id: "signin" },
    h("h2", { class: "words reveal" }, maskWords("Make your case.")),
    h("form", { class: "stack reveal", style: { "--i": 1 }, onSubmit },
      segments, username, password, error, submit),
    h("a", { class: "more-link reveal", style: { "--i": 2, alignSelf: "center" }, href: "#/join" }, "Have a room code? Join a round", icon("chevron")));

  const toSignin = (e) => {
    e.preventDefault();
    signin.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    setTimeout(() => username.focus({ preventScroll: true }), 600);
  };

  const heroTitle = h("h1", { class: "words reveal", style: { "--i": 1 } }, maskWords("Say it ", h("span", null, h("span", { class: "mark-word" }, "better"), ".")));
  const hero = h("header", { class: "hero" },
    h("div", { class: "reveal" }, logoMark(26)),
    heroTitle,
    h("div", { class: "hero-actions reveal", style: { "--i": 3 } },
      h("a", { class: "button primary", href: "#signin", onClick: toSignin }, "Get started"),
      h("a", { class: "more-link", href: "#/join" }, "Join a round", icon("chevron"))));

  const bubbles = [
    ["Opponent · Negative", "Colonization money could end famine on Earth today. A moral imperative can't ask the poor to pay for a hypothetical future.", ""],
    ["You · Affirmative", "Space research already funds the satellites that predict famine. Expansion is how we stop treating the future as disposable.", "mine"],
    ["Coach", "Strong turn. You answered the biggest impact first, then extended your framework.", "coach"],
  ].map(([who, text, cls]) => h("div", { class: `mock-bubble ${cls}` }, h("span", { class: "mock-speaker" }, who), h("p", null, text)));
  const meters = [["Filler words", 96], ["Smoothness", 88], ["Tone", 92]].map(([label, value]) => {
    const fill = h("span", { class: "mock-fill" });
    return { value, fill, el: h("div", { class: "mock-meter" }, h("span", { class: "kv-line" }, h("span", null, label), h("span", { class: "strong" }, String(value))), h("span", { class: "mock-track" }, fill)) };
  });
  const mockClock = h("span", { class: "mock-clock" }, "4:00");
  const mockScore = h("span", null, "0");
  const device = h("div", { class: "device", "aria-hidden": "true" },
    h("div", { class: "device-bar" },
      h("span", { class: "device-dots" }, h("i"), h("i"), h("i")),
      h("span", { class: "device-title" }, "Lincoln-Douglas · Your rebuttal"),
      mockClock),
    h("div", { class: "device-body" },
      h("div", { class: "device-main" },
        h("p", { class: "device-topic" }, "Resolved: Outer space colonization is a moral imperative."),
        bubbles),
      h("div", { class: "device-side" },
        h("span", { class: "subtext small" }, "Live delivery"),
        h("div", { class: "device-score" }, mockScore, h("span", null, "%")),
        meters.map((m) => m.el))));
  const showcase = h("section", { class: "showcase" }, device);

  const story = wordReveal("Verbatim takes the other side, keeps the clock, judges the round, and hands back your strongest line exactly as you said it.");
  const storySection = h("section", { class: "story" }, h("div", { class: "story-stage" }, story));

  const fillerDemo = h("div", { class: "demo reveal" },
    h("span", { class: "subtext small" }, "Your rebuttal · live delivery score"),
    h("p", { class: "speech" },
      h("span", { class: "filler" }, "Um,"), " my opponent says rights are ", h("span", { class: "filler" }, "like,"),
      " unenforceable. ", h("span", { class: "filler" }, "Basically,"), " we already give standing to corporations."),
    h("div", { class: "score" }, h("strong", null, "85"), h("span", { class: "subtext" }, "% delivery")));
  const scoreEl = fillerDemo.querySelector(".score strong");

  const quoteDemo = h("div", { class: "demo reveal" },
    h("span", { class: "subtext small" }, "Ballot · your strongest line"),
    h("p", { class: "quote" }, "“Rivers are being treated as property to be ", h("mark", null, "used up"), ".”"));

  const clock = h("div", { class: "speech-clock-time" }, "4:00");
  const clockDemo = h("div", { class: "demo reveal" },
    h("span", { class: "subtext small" }, "Judiciary · your constructive"),
    clock,
    h("div", { class: "bar" }, h("div", { class: "bar-fill", style: { width: "100%", transition: "none" } })));
  const clockBar = clockDemo.querySelector(".bar-fill");

  const chapter = (title, demo, extra = "") => h("section", { class: `chapter ${extra}` },
    h("div", { class: "reveal" }, h("h2", { class: "words reveal" }, maskWords(title))),
    demo);

  const el = h("div", { class: "welcome" },
    hero,
    showcase,
    storySection,
    chapter("Hear every um.", fillerDemo),
    h("div", { class: "dark-band" },
      chapter("Your best line, highlighted.", quoteDemo, "flip")),
    chapter("Model Congress, on the clock.", clockDemo),
    signin);

  const stops = [
    trackProgress(heroTitle, { onProgress: (p) => heroTitle.style.setProperty("--p", Math.min(1, 0.15 + p * 1.6).toFixed(3)) }),
    trackProgress(showcase, { onProgress: (p) => {
      const rise = Math.min(1, Math.max(0, (p - 0.04) / 0.36));
      const fill = Math.min(1, Math.max(0, (p - 0.3) / 0.25));
      device.style.setProperty("--q", rise.toFixed(4));
      bubbles.forEach((b, i) => b.classList.toggle("on", p > 0.22 + i * 0.09));
      meters.forEach((m) => { m.fill.style.width = `${m.value * fill}%`; });
      mockScore.textContent = String(Math.round(92 * fill));
      const left = Math.round(240 - fill * 78);
      mockClock.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
    } }),
    trackProgress(storySection, { sticky: true, onProgress: (p) => story.update(p) }),
    trackProgress(fillerDemo, { onProgress: (p) => {
      const q = Math.min(1, Math.max(0, (p - 0.2) * 2));
      fillerDemo.style.setProperty("--p", q.toFixed(3));
      scoreEl.textContent = String(Math.round(85 + q * 15));
    } }),
    trackProgress(quoteDemo, { onProgress: (p) => quoteDemo.style.setProperty("--p", Math.min(1, Math.max(0, (p - 0.25) * 2.5)).toFixed(3)) }),
    trackProgress(clockDemo, { onProgress: (p) => {
      const q = Math.min(1, Math.max(0, (p - 0.15) * 1.6));
      const left = Math.round(240 * (1 - q));
      clock.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
      clockBar.style.width = `${(1 - q) * 100}%`;
    } }),
  ];

  return { el, title: "Practice debate", destroy: () => stops.forEach((stop) => stop()) };
}
