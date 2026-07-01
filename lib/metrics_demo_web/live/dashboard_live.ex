defmodule MetricsDemoWeb.DashboardLive do
  @moduledoc """
  Live dashboard that renders the latest metrics snapshot and re-renders once
  per second as `MetricsDemo.Collector` broadcasts over PubSub. Updates reach
  the browser over the LiveView socket — no hand-rolled WebSocket.
  """

  use MetricsDemoWeb, :live_view

  alias MetricsDemo.Collector
  alias MetricsDemoWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Collector.subscribe()
    {:ok, assign(socket, metrics: Collector.latest())}
  end

  @impl true
  def handle_info({:metrics, metrics}, socket) do
    {:noreply, assign(socket, metrics: metrics)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="wrap">
      <header>
        <div class="brand">
          <div class="logo" aria-hidden="true">
            <svg viewBox="0 0 76 65" fill="currentColor">
              <path d="M37.59.25l36.95 64H.64l36.95-64z" />
            </svg>
          </div>
          <div>
            <h1>Live System Metrics</h1>
            <div class="sub">Elixir · Phoenix LiveView on Vercel</div>
          </div>
        </div>
        <div class="status"><span class="dot"></span><span class="status-text"></span></div>
      </header>

      <div class="grid">
        <div class="card span-2">
          <div class="label">CPU Utilization</div>
          <div>
            <span class="value">{Format.decimal(@metrics.cpu.utilization, 1)}<span class="unit">%</span></span>
          </div>
          <div class="meta">{@metrics.cpu.cores} cores · run queue {@metrics.cpu.run_queue}</div>
          <canvas
            id="cpu-spark"
            phx-hook="Spark"
            data-value={@metrics.cpu.utilization}
            data-ts={@metrics.timestamp}
            data-color="#0070f3"
            width="600"
            height="52"
          ></canvas>
        </div>

        <div class="card span-2">
          <div class="label">System Memory</div>
          <div>
            <span class="value">{Format.decimal(@metrics.memory.percent, 1)}<span class="unit">%</span></span>
          </div>
          <div class="meta">
            {Format.bytes(@metrics.memory.used)} / {Format.bytes(@metrics.memory.total)} used
          </div>
          <div class="bar">
            <span style={"width:#{min(100, @metrics.memory.percent)}%"}></span>
          </div>
          <canvas
            id="mem-spark"
            phx-hook="Spark"
            data-value={@metrics.memory.percent}
            data-ts={@metrics.timestamp}
            data-color="#00b8a3"
            width="600"
            height="52"
          ></canvas>
        </div>

        <div class="card">
          <div class="label">Load Average</div>
          <div><span class="value">{Format.decimal(@metrics.cpu.load_avg_1m, 2)}</span></div>
          <div class="meta">
            1m {Format.decimal(@metrics.cpu.load_avg_1m, 2)} · 5m {Format.decimal(
              @metrics.cpu.load_avg_5m,
              2
            )}
          </div>
        </div>

        <div class="card">
          <div class="label">BEAM Processes</div>
          <div><span class="value">{Format.integer(@metrics.beam.process_count)}</span></div>
          <div class="meta">of {Format.integer(@metrics.beam.process_limit)} limit</div>
        </div>

        <div class="card">
          <div class="label">BEAM Memory</div>
          <div><span class="value">{Format.bytes(@metrics.beam.memory_total)}</span></div>
          <div class="meta">total allocated</div>
        </div>

        <div class="card">
          <div class="label">Uptime</div>
          <div><span class="value">{Format.uptime(@metrics.beam.uptime_ms)}</span></div>
          <div class="meta">since boot</div>
        </div>
      </div>

      <footer>
        <div>Streaming once per second over <code>Phoenix LiveView</code></div>
        <div class="credit">
          Made by
          <a href="https://github.com/sponsors/franky47" target="_blank" rel="noopener noreferrer">François Best</a>
          · <a href="https://github.com/franky47/vercelixir" target="_blank" rel="noopener noreferrer">Source on GitHub</a>
        </div>
      </footer>
    </div>
    """
  end
end
