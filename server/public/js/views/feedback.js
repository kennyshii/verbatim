import { isJudged, isMultiplayer, namesOn, sectionTitles } from "../data.js";
import * as api from "../api.js";
import { analyzeTurns } from "../metrics.js";
import { speak, stop as stopSpeaking } from "../speech.js";
import * as store from "../store.js";
import { feedbackSections, h, judgeDecision, meterBar, pageHeader, replace, sectionLabel, topicBox } from "../ui.js";

export function deliveryCard(config, transcript) {
  const meters = isMultiplayer(config.mode) && config.participants?.length
    ? config.participants.map((p) => meterBar(analyzeTurns(transcript.filter((m) => m.speaker === p.name).map((m) => m.text)), { title: `${p.name} — presentational accuracy` }))
    : [meterBar(analyzeTurns(transcript.filter((m) => m.role === "user").map((m) => m.text)))];
  return h("section", { class: "card stack" },
    sectionLabel("Delivery"),
    meters,
    h("p", { class: "subtext small" }, "Filler words cost 5 points each. Smoothness looks at run-ons, fragments, and stumbles; tone looks for hedging or an overheated voice. Aim for 90 or higher."));
}

export function resultView(result, config) {
  return result.type === "judge"
    ? judgeDecision(result.decision, { affirmative: namesOn(config, "Affirmative"), negative: namesOn(config, "Negative"), language: config.language })
    : feedbackSections(result.feedback, { kind: config.kind, language: config.language });
}

export default function feedbackView({ app }) {
  const pending = app.pending.feedback;
  if (!pending) {
    queueMicrotask(() => app.goHome());
    return { el: h("div") };
  }
  const { config, transcript } = pending;
  const judged = isJudged(config.mode);
  const home = config.kind === "congress" ? "congress" : "debate";
  const content = h("div", { class: "stack-lg" });
  const done = h("button", { type: "button", class: "button secondary compact", onClick: () => { stopSpeaking(); app.pending.feedback = null; app.goHome(home); } }, "Done");

  function render() {
    done.disabled = pending.loading;
    if (pending.loading) {
      return replace(content, h("div", { class: "loading" }, h("span", { class: "spinner" }), judged ? "The judge is deciding…" : "Generating feedback…"));
    }
    if (pending.error) {
      return replace(content, h("div", { class: "card error-card" },
        h("p", { class: "error" }, pending.error),
        h("button", { type: "button", class: "button secondary compact", onClick: generate }, "Retry")));
    }
    replace(content,
      resultView(pending.result, config),
      deliveryCard(config, transcript),
      pending.saved ? h("p", { class: "subtext small" }, "Saved to your progress.") : null);
  }

  async function generate() {
    if (pending.saved || pending.loading) return render();
    pending.loading = true;
    pending.error = "";
    render();
    const prefs = store.prefs();
    try {
      if (judged) {
        const decision = await api.ai.judge(config, transcript);
        pending.result = { type: "judge", decision };
        if (prefs.readAloud) speak(`Decision: ${decision.winner}. ${decision.reasonForDecision}`, config.language);
      } else {
        const feedback = await api.ai.feedback(config, transcript);
        pending.result = { type: "coach", feedback };
        if (prefs.readAloud) {
          const t = sectionTitles(config.kind);
          speak(`${t[0]}. ${feedback.strongestArgument}. ${t[1]}. ${feedback.weakestArgument}. ${t[2]}. ${feedback.missedRebuttal}. ${t[3]}. ${feedback.suggestion}`, config.language);
        }
      }
      store.saveSession(app.user.id, config, transcript, pending.result);
      pending.saved = true;
    } catch (e) {
      pending.error = e.message;
    }
    pending.loading = false;
    pending.render();
  }

  const el = h("div", { class: "page narrow" },
    pageHeader({ title: judged ? "Decision" : "Feedback", actions: [done] }),
    topicBox(config.kind === "congress" ? config.committee : "Resolution", config.topic, `${config.mode} · ${config.difficulty} · ${config.language}`),
    content);

  pending.render = render;
  generate();
  return { el, title: judged ? "Decision" : "Feedback" };
}
