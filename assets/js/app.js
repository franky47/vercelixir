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

    ctx.beginPath()
    data.forEach((v, i) => {
      const px = x(start + i), py = y(v)
      i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
    })
    ctx.lineTo(x(HISTORY - 1), h)
    ctx.lineTo(x(start), h)
    ctx.closePath()
    const grad = ctx.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, color + "40")
    grad.addColorStop(1, color + "00")
    ctx.fillStyle = grad
    ctx.fill()

    ctx.beginPath()
    data.forEach((v, i) => {
      const px = x(start + i), py = y(v)
      i === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
    })
    ctx.strokeStyle = color
    ctx.lineWidth = 1.75
    ctx.lineJoin = "round"
    ctx.stroke()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { Spark }
})

window.liveSocket = liveSocket

// Cost control: hold the socket open only while the tab is visible so the Vercel
// instance can pause (provisioned memory is billed only while a connection is
// open). This also makes the initial connect, based on the load-time state.
function applyVisibility() {
  const root = document.documentElement
  if (document.hidden) {
    root.classList.add("paused")
    liveSocket.disconnect()
  } else {
    root.classList.remove("paused")
    liveSocket.connect()
  }
}

document.addEventListener("visibilitychange", applyVisibility)
applyVisibility()
