# Debate relay server

Keeps online rounds (1v1, 2v2, Team vs AI) in sync between phones. Zero dependencies.

```
node server.js            # listens on http://localhost:8787
PORT=3000 node server.js  # any port
```

Rooms live in memory and expire after six hours. Deploy anywhere that runs Node 18+
(Render, Railway, Fly.io, a Raspberry Pi) and paste the public URL into the app under
Settings → Online rounds → Relay server.

For the iOS simulator, `http://localhost:8787` works out of the box.
