# Authoring Elixir for Vercel

Notes from shipping this repo — a containerized Elixir/OTP app streaming system
metrics over WebSocket — to Vercel's Dockerfile + WebSocket support, which both
run on **Fluid compute**.

## TL;DR — the traps that cost time

1. **`Dockerfile.vercel` alone is not enough.** A CLI-created project deploys
   *statically* and silently ignores the Dockerfile until the project framework
   is `container`. Symptom: every route 404s with `x-vercel-error: NOT_FOUND`.
   Fix: commit `vercel.json` → `{ "framework": "container" }`.
2. **CLI must be ≥ 47.2.2.** Older versions error: *"This endpoint requires
   version 47.2.2 or later."*
3. **Memory floor is 2 GB** (Pro). You cannot provision lower. The cost lever is
   connection-time, not instance size.
4. The server **must listen on `$PORT`** (defaults to `80`) and bind `0.0.0.0`.

## The app

- **Phoenix LiveView** on a **Bandit**-backed `Phoenix.Endpoint`. `DashboardLive`
  serves `/`, subscribes to the collector, and re-renders each tick; updates ride
  the LiveView socket, so there is no hand-rolled `/ws`. **Jason** for encoding.
- **`:os_mon`** (`:cpu_sup`, `:memsup`) for host CPU/memory — it's part of OTP,
  so just add `:os_mon` to `extra_applications`. Disable `disksup`/`os_sup` and
  raise `system_memory_high_watermark` to avoid alarm log noise.
- One **`Collector` GenServer** samples once per second and broadcasts the
  snapshot **map** over **`Phoenix.PubSub`**. Centralising the cadence matters:
  `:cpu_sup.util/0` reports usage *since its previous call*, so it's only
  meaningful from a single caller — and you sample once per tick regardless of
  client count.
- Read the port from `$PORT` in `config/runtime.exs`; bind `ip: {0,0,0,0}`.
- Socket leaks aren't a concern: PubSub monitors subscriber pids and reaps them
  on exit, so closed LiveViews clean themselves up.

## LiveView specifics (the things that bite)

- **Assets need a build step.** LiveView's client JS (`phoenix`,
  `phoenix_live_view`) must reach the browser, or the page renders dead and never
  updates. `esbuild` bundles `assets/js/app.js`; the Dockerfile runs
  `mix assets.deploy` (esbuild `--minify` + `phx.digest`) before `mix release`,
  and the digested output ships inside the release's `priv/static`.
- **`secret_key_base` is required** to sign the session/LiveView. Prod reads
  `SECRET_KEY_BASE`, falling back to a per-boot random value — fine for a
  single-instance demo (a restart just forces clients to remount), but set the
  env var for anything real.
- **`check_origin: false`.** Vercel serves under a dynamic host, so origin
  checking on the LiveView socket is disabled. Lock it to your domain in prod.
- A LiveView socket is still **one long-running connection per viewer**, so the
  Fluid cost model below is unchanged. The client drops the socket on
  `visibilitychange` (hidden tab) to let the instance pause.

## Dockerfile.vercel

Multi-stage: build an OTP release on a Debian-based Elixir image, copy onto a
slim runtime.

- **Match the Debian suite** across builder and runner (both `bookworm` here).
  The release bundles ERTS (`include_erts: true`), so a glibc mismatch fails at
  runtime with `GLIBC_… not found`. Pin by `@sha256` digest for reproducibility.
- **Runtime libs:** `libstdc++6`, `openssl` (pulls `libssl3` for the crypto NIF),
  `libncurses6` (libtinfo), `ca-certificates`.
- **`ENV RELEASE_DISTRIBUTION=none`** — single-node deploy, so drop epmd and the
  distribution listener (removes attack surface and a hostname-resolution boot
  dependency). Trade-off: `bin/<app> rpc|remote` stop working (they need
  distribution); fine for production.
- **`CMD ["/app/bin/<app>", "start"]`** — for a *mix release*, `start` runs in
  the foreground (unlike rebar3/relx, where `start` daemonises and the container
  would exit).
- `:os_mon`'s port programs (`cpu_sup`, `memsup`) ship inside the bundled ERTS,
  so they work on the slim runtime with no extra packages.

## Making Vercel build the container (the #1 trap)

The CLI has a built-in **"Container" framework** (`slug: container`,
`useRuntime: @vercel/container`) whose detector is the presence of
`Dockerfile.vercel` / `Containerfile.vercel`. But detection only *sets* the
framework at dashboard import — a project created with `vercel link` stores
`framework: null`, and the build then respects that null and does a zero-config
**static** deploy: it copies `Dockerfile.vercel` into `.vercel/output/static/`
as a plain file, `builds` is empty, and every route 404s.

**Durable fix** (survives fresh clones / new projects):

```json
{ "$schema": "https://openapi.vercel.sh/vercel.json", "framework": "container" }
```

**One-off fix:**
`PATCH /v9/projects/<id>?teamId=<team>` with `{"framework":"container"}`.

> The `services` block in `vercel.json` looks like another route (it has a
> `memory` field in the CLI's internal schema), but Vercel's server-side
> validator **rejects** `type`, `routePrefix`, and `memory` under it. Only the
> top-level `framework` key works for a single container.

A correct deploy runs **buildah** on the build machine (pulls the base image,
runs your Dockerfile), pushes to `vcr.vercel.com`, and routes traffic to the
container on Fluid compute.

## WebSockets on Fluid

- A container is one long-running Bandit process, so a **single instance serves
  all WebSocket connections** — Fluid's per-connection pinning is automatic.
- WSS works with no extra config; derive the URL client-side from `location`
  (`wss:` under HTTPS).
- A held-open socket is a long-running in-flight request, so the instance stays
  **provisioned** (memory billed) for the life of the connection. When the last
  socket closes and no requests are in flight, the instance **pauses** → $0.

## Fast first paint: the static shell

A cold Fluid container takes **4–5 s to boot** before it can answer the first
HTTP request. Because LiveView server-renders `/` on that request, first paint is
held hostage to the cold start (worst on a hard reload). The fix is to serve a
**static skeleton from Vercel's edge** so paint never waits on the container; the
live numbers stream in once the socket connects.

You **cannot** just CDN-cache the LiveView dead render: it sets a per-visitor
session cookie + CSRF token, and Vercel refuses to cache any response with
`set-cookie`. A *skeleton* has neither, so it caches fine.

- **`GET /` → cookie-less skeleton.** A `serve_static_shell` plug at the front of
  the `:browser` pipeline short-circuits plain `GET /` with the skeleton and
  `halt`s *before* `fetch_session`/`protect_from_forgery` run — so no cookie, so
  Vercel caches it. Headers: `Vercel-CDN-Cache-Control: max-age=…,
  stale-while-revalidate=…` (edge-only, controls the cache) plus
  `Cache-Control: public, max-age=0, must-revalidate` (browser revalidates each
  load; the edge answers instantly). Confirm with `x-vercel-cache: HIT`.
- **`GET /?boot=1` → real dead render.** The client fetches this, grafts the
  `[data-phx-main]` container + CSRF meta into the skeleton, and connects. It's a
  distinct CDN cache key (and uncacheable anyway — it sets the cookie).

### The trap: keep the LiveView mounted at `/`

LiveView signs its session token to the **router path it's mounted at**. The
obvious-but-wrong design — skeleton at `/`, LiveView at a *separate* path like
`/app` — mints tokens bound to `/app` while the browser URL is `/`. On join the
server sees the URL doesn't match the view's route, answers with an
*unauthorized live_redirect*, and the client **falls back to a full page
request** → re-grafts → joins → redirects → **a tight reload loop** (hundreds of
reloads/min; on a metered instance that is a wallet fire).

So mount the LiveView at `/` and gate the skeleton with the `?boot` query
instead. Same route → tokens bound to `/` → the socket joins with no redirect,
and the URL never leaves `/` (so reloads stay instant too). As a backstop,
`app.js` keeps a short sessionStorage **loop-breaker** that aborts after a few
boots in quick succession.

### What it does and doesn't buy

- **Buys:** first paint is independent of the container — instant chrome from the
  edge even on a stone-cold instance, and `idle = $0` is preserved (no keep-warm).
- **Doesn't buy:** the live *data* still waits for the socket to reach a warm
  container, so on a genuinely cold hit the numbers fill in ~4–5 s after the
  (instant) skeleton. The first request per deploy also cold-fills the cache;
  `stale-while-revalidate` then serves stale-but-instant while revalidating.

### Cache freshness across deploys (verify on the platform)

The cached skeleton embeds the **digested** `app.js` URL (prod sets
`cache_static_manifest`), and `phx-track-static` forces the skeleton and the
boot render to reference the *same* asset URL — so they can't be split into
digested/un-digested. This is safe **only if Vercel scopes the CDN cache per
deployment** (the production alias swaps to a fresh-cache deployment, so a cached
skeleton never outlives the assets it points at). The research says it does;
confirm on your first redeploy that an old skeleton isn't served against new
assets (a stale digest would 404 → stuck skeleton). If a deploy ever shares the
cache, the fix is to reference `app.js` un-digested in `Layouts.head` (losing
`phx-track-static`'s auto-reload-on-deploy, but stable across deploys).

## Cost model

Billing dimensions (Fluid):

- **Active CPU** — billed *only while code executes* (paused during I/O / idle).
  A 1 s metrics tick is ~negligible CPU.
- **Provisioned Memory** — GB-hours for the *entire instance lifetime*, including
  while idle holding a connection. **This dominates** for a persistent socket.
- **Invocations** — one per connection; negligible.

Key facts:

- **2 GB is the floor on Pro** (Standard 2 GB / 1 vCPU, or Performance 4 GB /
  2 vCPU). `vercel.json` `memory` is rejected; the dashboard offers only those
  two tiers. Hobby is also 2 GB.
- `iad1` rates: **$0.128 / CPU-hr**, **$0.0106 / GB-hr**.
- So the real cost lever is **connection-time, not size**. Idle = $0; one viewer
  connected 24/7 ≈ $15/mo (mostly memory), covered by Pro's $20 credit.
- **Client lever:** close the WebSocket on `visibilitychange` when the tab is
  hidden, reopen on return. A backgrounded tab then stops holding the instance
  alive instead of billing 24/7.

In this deploy, `:memsup`/`:cpu_sup` reported the instance's *own* allocation
(2 GB, 1 vCPU; `System.schedulers_online/0` = 1), not the underlying host.

## Deploy

```sh
# one-time: create + link the project (picks the team scope)
vercel link --yes --project <name>

# framework is declared in vercel.json (see above); then:
vercel deploy --prod --yes --scope <team>
```

Fluid compute must be enabled (default for new projects). Use a recent CLI; if a
newer CLI reports "Not authorized" against a cached session, pass `--token`
explicitly.

## Verifying

- **Local:** `docker build -f Dockerfile.vercel -t app .` then
  `docker run -e PORT=8080 -p 8080:8080 app`; curl `/healthz`; drive the page in
  a browser to confirm the socket streams.
- The app **reporting its own cgroup memory** is a convenient oracle — it shows
  the real provisioned size and proves you're reading the container, not the Mac.
- After deploy, confirm it's a container (not static): the alias serves the app
  (200) instead of 404, and the project framework reads `container`.
