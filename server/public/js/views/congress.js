import { COMMITTEES, CONGRESS_SCRIPT, SIDES } from "../data.js";
import { reveal } from "../motion.js";
import * as api from "../api.js";
import { ACCEPT, extract, suggestedTitle } from "../document.js";
import * as store from "../store.js";
import { chip, h, icon, modal, navRow, optionCard, pageHeader, readAloudButton, replace, richText, sectionLabel } from "../ui.js";
import { aiWarning } from "./home.js";
import { difficultySection } from "./setup.js";

export function congressListView() {
  const search = h("input", { type: "search", class: "field", placeholder: "Search committees", "aria-label": "Search committees" });
  const list = h("div", { class: "stack" });

  function render() {
    const q = search.value.trim().toLowerCase();
    const filtered = COMMITTEES.filter((c) => !q || c.name.toLowerCase().includes(q) || c.jurisdiction.toLowerCase().includes(q));
    replace(list, filtered.length
      ? filtered.map((c, i) => {
          const row = navRow({ iconName: "congress", title: c.name, badge: c.chamber, href: `#/congress/${c.slug}` });
          row.classList.add("reveal");
          row.style.setProperty("--i", String(i % 2));
          return row;
        })
      : h("div", { class: "card empty" }, "No committee matches that search."));
    reveal(list);
  }
  search.addEventListener("input", render);
  render();

  const el = h("div", { class: "page" },
    pageHeader({ title: "Model Congress" }),
    h("div", { class: "stack-lg" },
      search,
      sectionLabel("Committees"),
      h("div", { class: "committee-grid" }, list)));
  return { el, title: "Model Congress" };
}

const sourceLink = (source, compact = false) => h("a", { class: `source-link${compact ? " card" : ""}`, href: source.url, target: "_blank", rel: "noopener" },
  icon("link", "icon accent"),
  h("span", { class: "source-body" }, h("span", null, source.title), compact ? null : h("span", { class: "subtext small" }, source.url.replace("https://", ""))),
  icon("external", "icon muted"));

function statLookup(app, committee, language) {
  modal("Look up a statistic", () => {
    const question = h("textarea", { class: "field", rows: "2", placeholder: "e.g. How many satellites are in orbit right now?", "aria-label": "Your question" });
    const button = h("button", { type: "button", class: "button primary", onClick: () => lookUp() }, "Look it up");
    const results = h("div", { class: "stack" });
    let loading = false;
    let answer = null;
    let error = "";

    const sync = () => { button.disabled = loading || !question.value.trim(); button.textContent = loading ? "Looking it up…" : "Look it up"; };
    question.addEventListener("input", sync);

    function render() {
      sync();
      replace(results,
        !answer && !loading ? [sectionLabel("Suggested for this committee"),
          committee.statSuggestions.map((sug) => h("button", { type: "button", class: "card suggestion", onClick: () => { question.value = sug; lookUp(); } }, icon("sparkle", "icon accent"), h("span", null, sug)))] : null,
        error ? h("p", { class: "error" }, error) : null,
        answer ? [
          h("section", { class: "card stack-sm" },
            h("div", { class: "feedback-head" }, sectionLabel("Result"), readAloudButton(answer, language)),
            richText(answer)),
          sectionLabel("Check it here"),
          committee.sources.map((src) => sourceLink(src, true)),
        ] : null);
    }

    async function lookUp() {
      const text = question.value.trim();
      if (!text || loading) return;
      loading = true;
      error = "";
      answer = null;
      render();
      try {
        answer = await api.ai.statLookup(text, committee.fullName, language);
      } catch (e) {
        error = e.message;
      }
      loading = false;
      render();
    }

    render();
    return h("div", { class: "stack" },
      question, button, results);
  });
}

export function committeeView({ params, app }) {
  const committee = COMMITTEES.find((c) => c.slug === params[0]);
  if (!committee) {
    queueMicrotask(() => app.go("/congress"));
    return { el: h("div") };
  }
  const prefs = store.prefs();
  const state = { billChoice: committee.bills[0], useUpload: false, uploadedText: "", uploadedName: "", side: "Affirmative", difficulty: "Medium", importError: "", reading: false };

  const fileInput = h("input", { type: "file", accept: ACCEPT, hidden: true });
  const titleInput = h("textarea", { class: "field", rows: "2", placeholder: "A Bill to…", "aria-label": "Bill title used in the round" });
  titleInput.addEventListener("input", renderStart);

  fileInput.addEventListener("change", async () => {
    const file = fileInput.files[0];
    fileInput.value = "";
    if (!file) return;
    state.importError = "";
    state.reading = true;
    render();
    try {
      const text = await extract(file);
      state.uploadedText = text;
      state.uploadedName = file.name;
      titleInput.value = suggestedTitle(text, file.name);
      state.useUpload = true;
    } catch (e) {
      state.importError = e.message;
    }
    state.reading = false;
    render();
  });

  const resolvedBill = () => (state.useUpload ? titleInput.value.trim() : state.billChoice);

  const body = h("div", { class: "stack-xl" });
  const startArea = h("div", { class: "stack" });
  const summary = h("div", { class: "summary-card" });

  function renderSummary() {
    const bill = resolvedBill();
    const row = (label, value) => h("div", { class: "kv" }, h("span", { class: "subtext" }, label), h("span", { class: "strong" }, value));
    replace(summary,
      h("span", { class: "eyebrow" }, `${committee.name} · ${committee.chamber}`),
      h("p", { class: `summary-topic${bill ? "" : " empty"}` }, bill || "Give your uploaded bill a title to see it here."),
      h("div", { class: "summary-rows" },
        row("Your side", state.side === "Affirmative" ? "Affirm the bill" : "Negate the bill"),
        row("Speeches", `${CONGRESS_SCRIPT.length} timed`),
        row("Difficulty", state.difficulty)));
  }

  function legislationSection() {
    const uploaded = Boolean(state.uploadedText);
    return h("section", { class: "stack" },
      sectionLabel("Legislation to debate"),
      committee.bills.map((bill) => optionCard({ title: bill, selected: !state.useUpload && state.billChoice === bill, onClick: () => { state.useUpload = false; state.billChoice = bill; render(); } })),
      optionCard({
        title: uploaded ? titleInput.value || state.uploadedName : state.reading ? "Reading the file…" : "Upload a bill",
        iconName: "upload",
        selected: state.useUpload,
        onClick: () => { if (!uploaded) fileInput.click(); else { state.useUpload = true; render(); } },
      }),
      h("div", { class: "button-row start" },
        h("button", { type: "button", class: "button secondary compact", onClick: () => fileInput.click() }, uploaded ? "Replace file" : "Choose file"),
        uploaded ? h("button", { type: "button", class: "button danger compact", onClick: () => { state.uploadedText = ""; state.uploadedName = ""; titleInput.value = ""; state.useUpload = false; render(); } }, "Remove") : null),
      state.importError ? h("p", { class: "error" }, state.importError) : null,
      state.useUpload && uploaded ? h("div", { class: "stack-sm" },
        h("label", { class: "field-label" }, "Bill title used in the round"),
        titleInput,
        h("details", { class: "preview" },
          h("summary", null, "Preview the text that was read"),
          h("p", { class: "subtext small pre" }, state.uploadedText.slice(0, 1500) + (state.uploadedText.length > 1500 ? "…" : "")))) : null,
      fileInput);
  }

  function sideSection() {
    return h("section", { class: "stack" },
      sectionLabel("Your side"),
      h("div", { class: "chips" }, SIDES.map((s) => chip({ label: s === "Affirmative" ? "Affirm the bill" : "Negate the bill", selected: state.side === s, onClick: () => { state.side = s; render(); } }))));
  }

  function formatSection() {
    return h("section", { class: "stack" },
      sectionLabel("Round format"),
      h("div", { class: "card format" },
        CONGRESS_SCRIPT.map((seg, i) => {
          const mine = (seg.stance === "Pro") === (state.side === "Affirmative");
          return h("div", { class: "format-row" },
            h("span", { class: `step-number${mine ? " mine" : ""}` }, String(i + 1)),
            h("span", { class: "grow" }, `${mine ? "You" : "AI member"} — ${seg.title} (${seg.stance})`),
            h("span", { class: "subtext small strong" }, seg.clock));
        }),
        h("hr"),
        h("div", { class: "format-row" }, icon("wave", "icon accent"), h("span", null, "Then you choose: speak again, or yield the floor and let the AI move an amendment if one is warranted.")),
        h("div", { class: "format-row" }, icon("question", "icon accent"), h("span", null, "Rise to a point of inquiry any time — a separate parliamentarian AI answers it."))));
  }

  function renderStart() {
    renderSummary();
    replace(startArea,
      aiWarning(app),
      h("button", { type: "button", class: "button primary", disabled: !resolvedBill(), onClick: start }, "Start Congress Round"));
  }

  function render() {
    replace(body,
      h("section", { class: "card tint stack-sm" },
        h("div", { class: "subtext small" }, committee.chamber),
        h("h2", { class: "accent-heading" }, committee.fullName)),
      h("section", { class: "stack" },
        sectionLabel("Agencies it oversees"),
        h("div", { class: "chips wrap" }, committee.agencies.map((a) => h("span", { class: "pill" }, a))),
        sectionLabel("Where to find reliable numbers"),
        h("div", { class: "card sources" }, committee.sources.map((src) => sourceLink(src))),
        h("button", { type: "button", class: "button secondary", onClick: () => statLookup(app, committee, prefs.language) }, icon("chart"), "Look up a statistic")),
      legislationSection(),
      sideSection(),
      difficultySection(state, render),
      formatSection());
    renderStart();
  }

  function start() {
    if (!resolvedBill()) return;
    app.pending.session = {
      kind: "congress", topic: resolvedBill(), language: prefs.language, difficulty: state.difficulty, mode: "Congress",
      userSide: state.side, participants: [], online: false, judgePreset: "Novice", committee: committee.fullName,
      billText: state.useUpload ? state.uploadedText : "", billFilename: state.useUpload ? state.uploadedName : "",
      lowPressure: prefs.lowPressure, plainLanguage: prefs.plainLanguage,
    };
    app.go("/session");
  }

  render();
  const el = h("div", { class: "page" },
    pageHeader({ title: committee.name, back: { href: "#/congress", label: "Committees" } }),
    h("div", { class: "split" },
      body,
      h("aside", { class: "split-side" }, summary, startArea)));
  return { el, title: committee.name, onStatus: renderStart };
}
