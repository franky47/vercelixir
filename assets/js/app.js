import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

const HISTORY = 60

// Sparkline driven by LiveView: `data-ts` changes every tick, so the canvas is
// always patched and `updated` runs even when `data-value` repeats.
const Spark = {
  mounted() {
    this.points = []
    this.ctx = this.el.getContext("2d")
    this.push()
  },
  updated() {
    this.push()
  },
  push() {
    const value = parseFloat(this.el.dataset.value)
    if (Number.isNaN(value)) return
    this.points.push(value)
    if (this.points.length > HISTORY) this.points.shift()
    this.draw()
  },
  draw() {
    const color = this.el.dataset.color || "#0070f3"
    const canvas = this.el
    const ctx = this.ctx
    const dpr = window.devicePixelRatio || 1
    const w = canvas.clientWidth
    const h = canvas.clientHeight
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr)
      canvas.height = Math.round(h * dpr)
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, w, h)

    const data = this.points
    if (data.length < 2) return
    const max = Math.max(100, ...data)
    const step = w / (HISTORY - 1)
    const y = (v) => h - 4 - (v / max) * (h - 8)
    const x = (i) => i * step
    const start = HISTORY - data.length

    const traceLine = () => {
      ctx.beginPath()
      data.forEach((v, i) => {
        const px = x(start + i), py = y(v)
        if (i === 0) ctx.moveTo(px, py)
        else ctx.lineTo(px, py)
      })
    }

    traceLine()
    ctx.lineTo(x(HISTORY - 1), h)
    ctx.lineTo(x(start), h)
    ctx.closePath()
    const grad = ctx.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, color + "40")
    grad.addColorStop(1, color + "00")
    ctx.fillStyle = grad
    ctx.fill()

    traceLine()
    ctx.strokeStyle = color
    ctx.lineWidth = 1.75
    ctx.lineJoin = "round"
    ctx.stroke()
  }
}

// The static shell at `/` is served from the CDN with no LiveView in the DOM.
// Fetch the real dead render from `/?boot=1` (the same `/` route, so its tokens
// are bound to this URL) and graft its LiveView container + CSRF token in, so
// the client can join as if the page had been server-rendered. When the dead
// render is already present (someone hit `/?boot=1` directly) there's nothing
// to do.
async function ensureLiveView() {
  if (document.querySelector("[data-phx-main]")) return

  const res = await fetch("/?boot=1", { headers: { accept: "text/html" } })
  if (!res.ok) throw new Error(`boot render responded ${res.status}`)

  const doc = new DOMParser().parseFromString(await res.text(), "text/html")
  const main = doc.querySelector("[data-phx-main]")
  if (!main) throw new Error("no LiveView container in boot render")

  const csrf = doc.querySelector("meta[name='csrf-token']")
  if (csrf) {
    const meta =
      document.querySelector("meta[name='csrf-token']") ||
      document.head.appendChild(Object.assign(document.createElement("meta"), { name: "csrf-token" }))
    meta.setAttribute("content", csrf.getAttribute("content"))
  }

  document.getElementById("dash-root").replaceWith(document.importNode(main, true))
}

function buildSocket() {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  window.liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken },
    hooks: { Spark }
  })
}

// Hard loop-breaker: a token/route mismatch makes LiveView fall back to a full
// page request, which re-runs this boot — a runaway reload loop (hundreds/min)
// that would keep a metered instance awake. Only boots closer than the window
// apart extend the streak, so the genuine loop trips in well under a second
// while a handful of impatient manual reloads (each gap ≥ the window) keep
// resetting to one. Storage failures fail open — never block a real user.
const BOOT_KEY = "lv-boot"
const MAX_BOOT_ATTEMPTS = 5
const LOOP_WINDOW_MS = 2000

function withinBootBudget() {
  let prev = null
  try {
    prev = JSON.parse(sessionStorage.getItem(BOOT_KEY))
  } catch {}

  const now = Date.now()
  const count = prev && now - prev.t < LOOP_WINDOW_MS ? prev.n + 1 : 1
  try {
    sessionStorage.setItem(BOOT_KEY, JSON.stringify({ n: count, t: now }))
  } catch {}
  return count <= MAX_BOOT_ATTEMPTS
}

let bootPromise = null
function ensureBooted() {
  if (!bootPromise) {
    bootPromise = (async () => {
      if (!withinBootBudget()) {
        throw new Error("LiveView reload loop detected; aborting boot")
      }

      await ensureLiveView()
      buildSocket()

      // Surviving a few seconds without a reload means we're stably connected.
      setTimeout(() => {
        try {
          sessionStorage.removeItem(BOOT_KEY)
        } catch {}
      }, 4000)
    })().catch((err) => {
      bootPromise = null // a transient cold-start failure can retry on the next visibility change
      document.getElementById("dash-root")?.classList.add("phx-error")
      throw err
    })
  }
  return bootPromise
}

// Cost control: graft + hold the socket open only while the tab is visible so the
// Vercel instance can pause (provisioned memory is billed only while a connection
// is open). The first visible tick also performs the initial boot + connect.
async function applyVisibility() {
  const root = document.documentElement
  if (document.hidden) {
    root.classList.add("paused")
    window.liveSocket?.disconnect()
    return
  }

  root.classList.remove("paused")
  try {
    await ensureBooted()
    // Boot can take seconds on a cold container; if the tab was hidden meanwhile,
    // don't connect — that would hold a billed socket open on an unwatched tab.
    if (!document.hidden) window.liveSocket.connect()
  } catch (err) {
    console.error("LiveView boot failed", err)
  }
}

document.addEventListener("visibilitychange", applyVisibility)
applyVisibility()
