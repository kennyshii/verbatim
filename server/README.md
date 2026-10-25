# Verbatim server

One Node process, zero dependencies (Node 20.12+). It serves three things:

- **The website** in `public/`: all of Verbatim in the browser (Debate, Congress, Progress, Settings).
- **The AI endpoints** under `/api/*`. Prompts are built here and sent to Claude with the server's key,
  so the key never reaches a browser and the endpoints can't be used as a general Claude proxy.
- **The relay** under `/rooms/*` that keeps online 1v1, 2v2, and Team vs AI rounds in sync. The iOS app
  uses the same relay, so phones and browsers can play in the same room.

## Run it

```
cp .env.example .env      # then paste your key after ANTHROPIC_API_KEY=
node server.js            # http://localhost:8787
```

Optional settings in `.env`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8787` | Port to listen on |
| `CLAUDE_MODEL` | `claude-sonnet-5` | Model used for every AI call |
| `AI_RATE_LIMIT` | `120` | AI requests allowed per connection every 10 minutes |
| `ACCESS_CODE` | unset | Visitors must enter this code before the site's AI endpoints respond |
| `TRUST_PROXY` | unset | Set when hosted behind a proxy so rate limits use `X-Forwarded-For` |
| `ANTHROPIC_BASE_URL` | `https://api.anthropic.com` | Point at a different API host |
| `GEMINI_API_KEY` | unset | Use Google Gemini instead when no `ANTHROPIC_API_KEY` is set |
| `GEMINI_MODEL` | `gemini-3.6-flash` | Gemini model used for every AI call; falls back to `gemini-flash-lite-latest` when Google reports high demand |
| `GEMINI_TTS_MODEL` | `gemini-3.8-flash-tts` | Gemini model that reads AI speeches aloud; browsers fall back to a built-in voice without it |
| `GEMINI_VOICE` | `Puck` | Gemini voice for read-aloud |

Accounts, sessions, and streaks are stored in each visitor's browser (like the app's on-device
SQLite), so the server keeps no user data. Rooms live in memory and expire after six hours.

Accounts need a secure context for password hashing: `localhost` works, and any hosted copy must use
https. The health check moved from `/` to `/health`.

## Sharing it with someone on another network

```
brew install cloudflared
cloudflared tunnel --url http://localhost:8787
```

This prints a temporary `https://….trycloudflare.com` link that works while your Mac, the server, and
the tunnel are running. Set `ACCESS_CODE` and `TRUST_PROXY=1` in `.env` first so only people you give
the code to can use your API key.
