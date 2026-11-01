# Verbatim

A website for practicing debate and Model Congress. You argue against an AI that argues back, get feedback on how you delivered your speech, and track how you improve. Made for the Congressional App Challenge.

**Try it:** https://verbatim-tvqw.onrender.com (it's on free hosting, so the first load can take up to a minute while the server wakes up)

**Demo video:** https://youtu.be/7XFuywRBj-E

## Features

- **Debate:** argue a resolution live against the AI, or use Coach mode for feedback after every turn. You can also play 1v1 or 2v2 against friends, or team up against the AI.
- **Speak or type:** tap the mic and your speech is transcribed as you talk.
- **Delivery feedback:** after a spoken turn you get a delivery score, a map of your claim, evidence and reasoning, and specific things to work on. Take 2 lets you re-record and compare.
- **Online rounds:** share a six-character code and friends can join without an account, with an AI judge giving the decision.
- **Model Congress:** all 16 real committees, a statistic lookup with sources, bill uploads, and full round format with points of inquiry.
- **Community:** post short recorded arguments and react to other students' takes.
- **Progress:** streaks, session counts, average delivery score and the skills that keep coming up in your feedback.
- **Settings:** language, a low-pressure mode, plain-language feedback and read-aloud replies.

## Running it locally

It's a single Node server with no dependencies (Node 20.12+). The server serves the site, makes the AI calls so no API key ever reaches the browser, and keeps online rounds in sync.

```
cd server
cp .env.example .env      # add ANTHROPIC_API_KEY=... or GEMINI_API_KEY=...
node server.js            # then open http://localhost:8787
```

It uses Claude if you give it an Anthropic key, or Google Gemini if you only give it a Gemini key. `server/README.md` lists every setting.

## Project layout

- `server/server.js`: the web server, AI endpoints and online-round relay
- `server/claude.js`: prompts and the Claude and Gemini calls
- `server/public/`: the website, with one file per screen in `js/views/`
- `render.yaml`: hosting config for Render

## Security

API keys stay on the server and are never committed. Passwords are hashed with PBKDF2, and AI requests are rate limited and size capped.
