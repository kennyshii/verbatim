import { DIFFICULTIES, JUDGE_PRESETS, SIDES, TOPIC_CATEGORIES, humanCount, isJudged, isMultiplayer, opposite } from "../data.js";
import * as api from "../api.js";
import * as store from "../store.js";
import { chip, h, icon, optionCard, pageHeader, replace, sectionLabel, subtext } from "../ui.js";
import { aiWarning } from "./home.js";
import { saveSeat } from "./online.js";

export function difficultySection(state, rerender) {
  return h("section", { class: "stack" },
    sectionLabel("Difficulty"),
    h("div", { class: "chips" }, DIFFICULTIES.map((d) => chip({ label: d.id, iconName: d.icon, selected: state.difficulty === d.id, onClick: () => { state.difficulty = d.id; rerender(); } }))),
    subtext(DIFFICULTIES.find((d) => d.id === state.difficulty).explanation));
}

export default function setupView({ query, app }) {
  const requested = query.get("mode");
  const mode = ["Debate", "Coach", "1v1", "2v2", "Team vs AI"].includes(requested) ? requested : "Debate";
  const initialTopic = query.get("topic");
  const multiplayer = isMultiplayer(mode);

  const state = {
    category: 0,
    useCustom: false,
    topicChoice: TOPIC_CATEGORIES[0].topics[0].text,
    difficulty: "Medium",
    online: false,
    userSide: "Affirmative",
    userRoleIsCase: true,
    judgePreset: "Novice",
    creating: false,
    createError: "",
  };

  if (initialTopic) {
    const index = TOPIC_CATEGORIES.findIndex((c) => c.topics.some((t) => t.text === initialTopic));
    if (index >= 0) { state.category = index; state.topicChoice = initialTopic; } else { state.useCustom = true; }
  }

  const input = (placeholder, value = "") => {
    const el = h("input", { type: "text", class: "field", placeholder, "aria-label": placeholder, value });
    el.addEventListener("input", renderFooter);
    return el;
  };
  const customTopic = h("textarea", { class: "field", rows: "2", placeholder: "e.g. Resolved: Cities should ban cars downtown.", "aria-label": "Your resolution" });
  customTopic.value = state.useCustom ? initialTopic : "";
  customTopic.addEventListener("input", renderFooter);
  const displayName = input("Your display name", app.user.username);
  const partnerName = input(mode === "2v2" ? "Your partner's name (second speaker on your side)" : "Your partner's name");
  const opponentName = input(mode === "2v2" ? "Opponent 1 (their first speaker)" : "Opponent's name");
  const opponent2Name = input("Opponent 2 (their second speaker)");

  const val = (el) => el.value.trim();
  const resolvedTopic = () => (state.useCustom ? val(customTopic) : state.topicChoice);

  function blocker() {
    if (!resolvedTopic()) return "Pick or write a resolution first.";
    if (!multiplayer) return null;
    if (state.online) return val(displayName) ? null : "Enter the display name other debaters will see.";
    if (mode === "1v1") return val(opponentName) ? null : "Enter your opponent's name to start.";
    if (mode === "2v2") return [partnerName, opponentName, opponent2Name].some((el) => !val(el)) ? "Name all four debaters to start." : null;
    if (mode === "Team vs AI") return val(partnerName) ? null : "Enter your partner's name to start.";
    return null;
  }

  const body = h("div", { class: "stack-xl" });
  const summary = h("div", { class: "summary-card" });
  const footer = h("div", { class: "stack" });

  function renderSummary() {
    const topic = resolvedTopic();
    const category = state.useCustom ? "Custom resolution" : TOPIC_CATEGORIES[state.category].name;
    const row = (label, value) => h("div", { class: "kv" }, h("span", { class: "subtext" }, label), h("span", { class: "strong" }, value));
    replace(summary,
      h("span", { class: "eyebrow" }, `${mode} · ${category}`),
      h("p", { class: `summary-topic${topic ? "" : " empty"}` }, topic || "Write your resolution to see it here."),
      h("div", { class: "summary-rows" },
        row("Your side", multiplayer ? state.userSide : "Affirmative"),
        multiplayer ? row("Playing", state.online ? "Online with a code" : "Same device") : row("Opponent", mode === "Coach" ? "None, just the coach" : "AI, Negative"),
        isJudged(mode) ? row("Judge", state.judgePreset) : null,
        row("Difficulty", state.difficulty)));
  }

  function topicSection() {
    const category = TOPIC_CATEGORIES[state.category];
    return h("section", { class: "stack" },
      sectionLabel("Resolution"),
      subtext(multiplayer ? "Pick sides below." : "You argue for it. In Debate mode the AI argues against."),
      h("div", { class: "chips scroll" },
        TOPIC_CATEGORIES.map((cat, i) => chip({ label: cat.name, iconName: cat.icon, selected: !state.useCustom && state.category === i, onClick: () => {
          state.category = i;
          state.useCustom = false;
          if (!cat.topics.some((t) => t.text === state.topicChoice)) state.topicChoice = cat.topics[0].text;
          render();
        } })),
        chip({ label: "Custom", iconName: "pencil", selected: state.useCustom, onClick: () => { state.useCustom = true; render(); customTopic.focus(); } })),
      state.useCustom
        ? h("div", { class: "stack-sm" },
            h("label", { class: "field-label" }, "Write your own resolution"),
            customTopic,
            subtext("Phrase it as a claim you can argue for, not a question."))
        : [category.topics.map((t) => optionCard({ title: t.text, subtitle: t.period, selected: state.topicChoice === t.text, onClick: () => { state.topicChoice = t.text; render(); } })),
           h("p", { class: "subtext small" }, "Topics from the National Speech & Debate Association: ",
             h("a", { href: category.source, target: "_blank", rel: "noopener" }, category.source))]);
  }

  function connectionSection() {
    const others = humanCount(mode) - 1;
    return h("section", { class: "stack" },
      sectionLabel("How are you playing?"),
      h("div", { class: "chips" },
        chip({ label: "Same device", iconName: "device", selected: !state.online, onClick: () => { state.online = false; render(); } }),
        chip({ label: "Online with a code", iconName: "wifi", selected: state.online, onClick: () => { state.online = true; render(); } })),
      state.online
        ? [subtext(`You'll get a six-character code to share. The other ${others === 1 ? "debater joins" : `${others} debaters join`} from their own device with "Join a round with a code" — no account needed.`), displayName]
        : [subtext("Pass this device around. Each debater types their speech when the header says it's their turn."),
           mode === "1v1" ? opponentName : null,
           mode === "2v2" ? [partnerName, opponentName, opponent2Name] : null,
           mode === "Team vs AI" ? partnerName : null],
      mode === "Team vs AI" ? [
        sectionLabel("Your role"),
        h("div", { class: "chips" },
          chip({ label: "I present the case", iconName: "doc", selected: state.userRoleIsCase, onClick: () => { state.userRoleIsCase = true; render(); } }),
          chip({ label: "I rebut", iconName: "rebut", selected: !state.userRoleIsCase, onClick: () => { state.userRoleIsCase = false; render(); } })),
        subtext(state.online ? "The first person to join takes the other role." : `${val(partnerName) || "Your partner"} takes the other role. The case speaker opens; the AI answers every speech and asks crossfire questions.`),
      ] : null);
  }

  function sidesSection() {
    const team = mode === "Team vs AI";
    return h("section", { class: "stack" },
      sectionLabel(team ? "Your team's side" : "Your side"),
      h("div", { class: "chips" }, SIDES.map((side) => chip({ label: `${team ? "We're" : "I'm"} ${side}`, selected: state.userSide === side, onClick: () => { state.userSide = side; render(); } }))),
      subtext(team
        ? `The AI argues the ${opposite(state.userSide).toLowerCase()} as both of its speakers.`
        : mode === "2v2"
          ? `Speaking order: first speakers alternate, then second speakers. ${state.userSide === "Affirmative" ? "Your team" : "The other team"} opens.`
          : "The affirmative speaks first."));
  }

  function judgeSection() {
    return h("section", { class: "stack" },
      sectionLabel("Judge"),
      h("div", { class: "chips" }, Object.keys(JUDGE_PRESETS).map((preset) => chip({ label: preset, iconName: preset === "Novice" ? "leaf" : "bolt", selected: state.judgePreset === preset, onClick: () => { state.judgePreset = preset; render(); } }))));
  }

  function renderFooter() {
    renderSummary();
    const reason = blocker();
    const label = state.creating ? "Creating Room…" : multiplayer ? (state.online ? "Create Room and Get Code" : `Start ${mode}`) : "Start Round";
    replace(footer,
      state.createError ? h("p", { class: "error" }, state.createError) : null,
      aiWarning(app),
      h("button", { type: "button", class: "button primary", disabled: Boolean(reason) || state.creating, onClick: start }, label),
      reason && !state.creating ? h("p", { class: "hint" }, icon("info"), reason) : null,
      h("p", { class: "ai-note" }, isJudged(mode) ? "The judge is AI. Its decision may contain mistakes." : "Your opponent and coach are AI. Replies may contain mistakes."));
  }

  function render() {
    replace(body,
      topicSection(),
      multiplayer ? connectionSection() : null,
      multiplayer ? sidesSection() : null,
      isJudged(mode) ? judgeSection() : null,
      difficultySection(state, render));
    renderFooter();
  }

  function participants() {
    const me = app.user.username;
    const opp = opposite(state.userSide);
    const p = (name, side, role, isUser) => ({ name, side, role, isUser });
    if (mode === "1v1") {
      const user = p(me, state.userSide, "Debater", true);
      const other = p(val(opponentName), opp, "Debater", false);
      return state.userSide === "Affirmative" ? [user, other] : [other, user];
    }
    if (mode === "2v2") {
      const user = p(me, state.userSide, "First speaker", true);
      const partner = p(val(partnerName), state.userSide, "Second speaker", false);
      const o1 = p(val(opponentName), opp, "First speaker", false);
      const o2 = p(val(opponent2Name), opp, "Second speaker", false);
      return state.userSide === "Affirmative" ? [user, o1, partner, o2] : [o1, user, o2, partner];
    }
    if (mode === "Team vs AI") {
      const user = p(me, state.userSide, state.userRoleIsCase ? "Case" : "Rebuttal", true);
      const partner = p(val(partnerName), state.userSide, state.userRoleIsCase ? "Rebuttal" : "Case", true);
      return state.userRoleIsCase ? [user, partner] : [partner, user];
    }
    return [];
  }

  async function start() {
    if (blocker()) return;
    const prefs = store.prefs();
    const config = {
      kind: "debate", topic: resolvedTopic(), language: prefs.language, difficulty: state.difficulty, mode,
      userSide: state.userSide, participants: [], online: false, judgePreset: state.judgePreset,
      committee: "", billText: "", billFilename: "", lowPressure: prefs.lowPressure, plainLanguage: prefs.plainLanguage,
    };
    if (multiplayer && state.online) {
      state.creating = true;
      state.createError = "";
      renderFooter();
      try {
        const { room, playerId } = await api.rooms.create(config, val(displayName));
        saveSeat(room.code, playerId);
        app.go(`/room/${room.code}`);
        return;
      } catch (e) {
        state.createError = e.message;
      }
      state.creating = false;
      renderFooter();
      return;
    }
    config.participants = participants();
    app.pending.session = config;
    app.go("/session");
  }

  render();

  const el = h("div", { class: "page" },
    pageHeader({ title: `Set up ${mode}`, back: { href: "#/debate", label: "Debate" } }),
    h("div", { class: "split" },
      body,
      h("aside", { class: "split-side" }, summary, footer)));
  return { el, title: `Set up ${mode}`, onStatus: renderFooter };
}
