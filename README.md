# Verbatim

**Verbatim** is a website that helps students practice debate and Model Congress against an AI that
argues back, get feedback on how they deliver a speech, and build confidence speaking. It was built for
the Congressional App Challenge.

**Try it:** https://verbatim-tvqw.onrender.com (free hosting, so the first load after a quiet period can
take up to a minute while the server wakes up)

**Demo video:** https://youtu.be/7XFuywRBj-E

## Run it locally

Verbatim is one Node server with no dependencies (Node 20.12+). It serves the site, makes the AI calls so
no key ever reaches a browser, and keeps online rounds in sync.

```
cd server
cp .env.example .env      # add ANTHROPIC_API_KEY=... or GEMINI_API_KEY=...
node server.js            # open http://localhost:8787
```

With an Anthropic key the AI runs on Claude; with only a Gemini key it runs on Google Gemini. See
`server/README.md` for every setting.

## What it does

### Home
- A **notepad** for organizing your thoughts before you speak, saved to your account.
- Featured resolutions from the National Speech & Debate Association, one tap away from a round.

### Debate
- **Modes:** Debate (the AI argues the other side live), Coach (low-pressure, feedback after every
  turn), 1v1 and 2v2 against friends, and Team vs AI with a live crossfire.
- **Topics:** current Lincoln-Douglas and Public Forum resolutions, or your own.
- **Speak instead of type:** tap the mic and talk; your speech is transcribed as you go.
- **Recording analysis:** after a spoken turn you get a separate page with your delivery score, a
  claim → evidence → reasoning map of your argument, and four specific ways to improve.
- **Take 2:** re-record the same argument and compare the two versions side by side.
- **Online rounds:** create a room and share a six-character code; friends join without an account,
  and an AI judge (Novice or Varsity) gives the decision and a reason for decision.
- **Feedback** at the end of every round: strongest point, weakest point, missed rebuttal, and a
  suggestion, plus filler, smoothness, and tone scores.

### Model Congress
- The 16 real committees, searchable, each with its jurisdiction.
- **Look up a statistic** in the committee's area, with the source that publishes it.
- **Upload a bill** (PDF, DOCX, TXT, RTF, Markdown) or pick a preset one.
- Full round format: authorship, constructive, second speech, closing, and open floor. The AI's
  speeches are read aloud and must be heard in full unless you confirm skipping twice.
- **Point of inquiry:** a separate parliamentarian AI rules on procedure and facts.

### Community
- **Take 2 feed:** record a short argument, post it, and like, comment on, and play other students'
  takes.

### Progress
- Daily and longest streaks, total sessions, average delivery score, your best lines, and the skills
  that keep coming up in feedback.

### Settings
- Language for every round and all feedback, low-pressure mode, plain-language feedback, read replies
  aloud, and a toggle for the filler meter.

## Where things are

| Path | Role |
| --- | --- |
| `server/server.js` | Web server: the site, the `/api` AI endpoints, and the relay for online rounds |
| `server/claude.js` | Prompts and the Claude / Gemini calls |
| `server/public/` | The website; `js/views/` has one file per screen |
| `render.yaml` | Hosting config for Render |
| `DebatePractice/` | The earlier native iOS prototype (SwiftUI + SQLite) |

## Privacy and security

- API keys live only on the server, never in the browser or this repo.
- Passwords are hashed with PBKDF2 before they are stored.
- AI requests are rate limited per visitor, and request sizes are capped.

## Branding

Navy `#1D2540`, cream `#F6F1E9`, coral `#EE7B5B`, from `verbatimlogo.png`. Type is EB Garamond (SIL Open
Font License).
