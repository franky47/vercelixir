# CLAUDE.md

Containerized Elixir/OTP app that streams host + BEAM metrics to a Phoenix
LiveView dashboard once per second. Deployed to Vercel as a Dockerfile container
on Fluid compute.

## Before touching deploy / Docker / Vercel

Read **[elixir-on-vercel.md](./elixir-on-vercel.md)** — it records the platform
gotchas learned the hard way. The big one: Vercel needs `framework: "container"`
in `vercel.json`, or it silently does a *static* deploy that 404s every route.

## Stack

- `lib/metrics_demo/` (core) — `Collector` (1 s sampler → `Phoenix.PubSub`
  broadcast of the metrics map), `Metrics` (`:os_mon` + BEAM stats).
- `lib/metrics_demo_web/` (web) — `Endpoint` (Bandit adapter), `Router`,
  `DashboardLive` (LiveView at `/`; subscribes to `Collector` and re-renders each
  tick), `Layouts.head` (shared `<head>` + inline CSS), `PageHTML.shell` (the
  static skeleton), `HealthController` (`/healthz`).
- **Static shell for fast first paint.** Plain `GET /` short-circuits in the
  `serve_static_shell` router plug with a cookie-less, CDN-cacheable skeleton, so
  Vercel's edge serves first paint without waiting on a cold container. The client
  then fetches `/?boot=1` (same `/` route → tokens bound to this URL) and grafts
  the real dead render in. See [elixir-on-vercel.md](./elixir-on-vercel.md).
- `assets/js/app.js` — boots the static shell (fetch `/?boot=1`, graft, connect),
  a `Spark` canvas hook for the sparklines, drops the socket while the tab is
  hidden (cost control), and a sessionStorage loop-breaker. Bundled by `esbuild`.
- `Dockerfile.vercel` — multi-stage OTP release; runs `mix assets.deploy`;
  listens on `$PORT` (default 80).

## Commands

```sh
mix setup                  # deps.get + esbuild install
mix run --no-halt          # local, http://localhost:4000 (or: mix phx.server)
mix test
docker build -f Dockerfile.vercel -t metrics-demo . && \
  docker run --rm -e PORT=8080 -p 8080:8080 metrics-demo
```
