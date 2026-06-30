# CLAUDE.md

Containerized Elixir/OTP app that streams host + BEAM metrics over a WebSocket
once per second, with a static dashboard. Deployed to Vercel as a Dockerfile
container on Fluid compute.

## Before touching deploy / Docker / Vercel

Read **[elixir-on-vercel.md](./elixir-on-vercel.md)** — it records the platform
gotchas learned the hard way. The big one: Vercel needs `framework: "container"`
in `vercel.json`, or it silently does a *static* deploy that 404s every route.

## Stack

- `lib/metrics_demo/` — `Collector` (1 s sampler → `:pg` broadcast),
  `MetricsSocket` (WebSock handler), `Metrics` (`:os_mon` + BEAM stats), `Router`
  (Bandit; serves the dashboard and upgrades `/ws`).
- `priv/static/index.html` — dependency-free dashboard; reconnects with backoff
  and disconnects while the tab is hidden (cost control).
- `Dockerfile.vercel` — multi-stage OTP release; listens on `$PORT` (default 80).

## Commands

```sh
mix deps.get && mix run --no-halt   # local, http://localhost:4000
mix test
docker build -f Dockerfile.vercel -t metrics-demo . && \
  docker run --rm -e PORT=8080 -p 8080:8080 metrics-demo
```
