# Debate Practice (iOS prototype)

A Congressional App Challenge prototype that helps students practice debate and Model Congress with
AI feedback, track their progress, and build confidence speaking. Native iOS app — SwiftUI + SQLite +
the Anthropic Messages API. No package dependencies.

## Run it

1. Open `DebatePractice.xcodeproj` in Xcode 16 or newer.
2. Pick an iPhone simulator (e.g. iPhone 17) and press ▶.
3. Sign up with any username/password.
4. On the Home screen tap the gear icon and paste an Anthropic API key. It's stored in the iOS
   Keychain (never in this repo). Get a key at https://console.anthropic.com/.

## What's built

### Debate Practice
- **Topics** — **Lincoln-Douglas** and **Public Forum**, carrying the current resolutions word-for-word
  from the National Speech & Debate Association (https://www.speechanddebate.org/topics/), each with its
  month range, plus a custom option. Five preset resolutions are suggested straight on the Home screen —
  tap one to go straight into setup with it loaded.
- **Debate** — the AI argues the opposing side live; structured feedback after you end.
- **Coach** — no opponent; structured feedback after every turn.
- **Briefing** — text-to-text. Send a draft of your points; get back a sharpened version and a list of
  what changed. For tightening your writing rather than practicing delivery.
- **1v1** — debate another person, on the same phone or **online with a six-character room code**.
- **2v2** — Public Forum style, two on two. First speakers alternate, then second speakers. Same phone
  or online; each debater speaks from their own device when the banner names them.
- **Team vs AI** — you and a partner on the same side: one presents the case, the other rebuts, while the
  AI plays *both* opposing speakers. Between the first affirmative and negative speeches there is a
  **crossfire**: the AI asks your team three questions, answered live one at a time, alternating between
  partners. Every AI speech also ends with two rhetorical crossfire questions to answer in your next turn.
- **Judges** — **Novice** and **Varsity** presets, each carrying a real sample reason for decision that the
  AI judge matches for voice, technical depth, and specificity, or write your own paradigm. The judge
  returns a decision, a reason for decision, and feedback for each side.

### Playing online
Multiplayer rounds sync through the tiny relay in `server/` (Node 18+, zero dependencies):

```
cd server && node server.js
```

The host picks "Online with a code" and gets a six-character code to share. Everyone else opens the app,
taps **Join a round with a code**, and enters it with their name — **no account needed on their end**, so
rounds work between people who aren't in the same room. Set the relay's URL in Settings → Online rounds
(the default `http://localhost:8787` works for the simulator; host it anywhere for real phones).

### Model Congress
- Every standing committee of the House and Senate plus the select and special committees (41 total),
  each with its jurisdiction, the agencies it oversees, and where to find reliable numbers (CBO, CRS,
  BLS, Census, agency data…).
- **Committee briefing** — an AI-prepared, saved briefing: live policy fights with the strongest argument
  on each side, figures worth knowing, and where to verify them. Any number the AI states is marked
  *(verify)*; where it isn't confident it names the dataset to check instead of guessing.
- **Congress round** — pick practice legislation (or write a bill), affirm or negate, and give speeches.
  An opposing member refutes you and asks one cross-examination question each turn; a parliamentarian
  scores you at the end on argumentation, evidence, organization, questioning, and decorum.

### Delivery: presentational accuracy
Three live bars under the composer, scored as you type, with a per-turn score on each bubble, a delivery
card on every feedback screen, and an average on the Progress dashboard:
- **Filler words** — starts at 100 and **deducts 5 points for every filler** (um, uh, like, you know,
  basically, literally, actually, kind of, sort of, sentence-opening "so," / "well,", trailing "right?"…).
- **Smoothness** — run-on sentences, fragments, repeated-word stumbles ("the the"), restarts and
  trailing off, comma-stuffed sentences.
- **Tone** — hedging ("I think", "maybe"), hostility, shouting, stacked punctuation, and overused
  absolutes, summarised as Confident and measured / Hedging / Overheated / Uneven.

The headline percentage weights them 40% filler, 30% smoothness, 30% tone.

### Stat checking
Whenever a speech contains a number, percentage, or dollar figure, a separate AI call checks it and a
**Stat check** note appears under that turn — "Likely accurate", "Questionable", or "Can't verify", each
with the source to confirm it against.
- On a real iPhone the keyboard's microphone dictates straight into the composer, so you can practice
  out loud and still get scored.

### Support & accessibility (Settings)
- **Low-pressure mode** — a short grounding step before each round, a calmer and more courteous
  opponent, shorter replies, and one or two points at a time. Same rigor, less intensity.
- **Plain-language feedback** — short sentences, everyday words, jargon defined.
- **Read replies aloud** — text-to-speech for AI replies, feedback, decisions, and briefings; a speaker
  button is always available even when auto-read is off.
- **Filler meter toggle** — hide the meter to reduce clutter.

### Progress
- Daily streak, longest streak, total sessions, average presentational accuracy.
- Every past session with its transcript, feedback or judge decision, and delivery score.
- Recurring feedback tags (Rebuttals, Evidence use, Structure, Clarity, Logical reasoning…) that keep
  showing up across sessions.

## Where things are

| File | Role |
| --- | --- |
| `DebatePractice/Models.swift` | Data types, NSDA topic catalog, committee catalog, judge presets |
| `DebatePractice/Data/Database.swift` | Thin SQLite3 wrapper + schema |
| `DebatePractice/Data/AuthStore.swift` | Signup / login / PBKDF2 hashing |
| `DebatePractice/Data/SessionStore.swift` | Sessions, streaks, saved briefings |
| `DebatePractice/Data/Keychain.swift` | API key storage |
| `DebatePractice/Services/ClaudeClient.swift` | Persona system prompts and the API calls |
| `DebatePractice/Services/FeedbackParser.swift` | Splits coach output and judge decisions into sections |
| `DebatePractice/Services/SpeechMetrics.swift` | Filler, smoothness, and tone scoring |
| `DebatePractice/Services/RoomClient.swift` | Online room codes, turns, and syncing |
| `server/server.js` | The relay server for online rounds |
| `DebatePractice/Services/Speaker.swift` | Text-to-speech |
| `DebatePractice/Services/TagExtractor.swift` | Recurring-feedback tagging |
| `DebatePractice/Views/` | One SwiftUI file per screen |

The model is set in `ClaudeClient.model`. The SQLite file lives in the app's Documents directory as
`debate.sqlite`.

## Out of scope (by design)

Speech recognition inside the app (use the keyboard microphone), email verification / password reset,
deployment of the relay. This is a local prototype:
calling the Anthropic API directly from the app is fine here, but a shipped version should put a small
server in between so the key never lives on a phone.
