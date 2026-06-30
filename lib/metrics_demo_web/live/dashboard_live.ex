defmodule MetricsDemoWeb.DashboardLive do
  @moduledoc """
  Live dashboard that renders the latest metrics snapshot and re-renders once
  per second as `MetricsDemo.Collector` broadcasts over PubSub. Updates reach
  the browser over the LiveView socket — no hand-rolled WebSocket.
  """

  use MetricsDemoWeb, :live_view

  alias MetricsDemo.Collector

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
            <span class="value">{fmt(@metrics.cpu.utilization, 1)}<span class="unit">%</span></span>
          </div>
          <div class="meta">{@metrics.cpu.cores} cores · run queue {@metrics.cpu.run_queue}</div>
          <canvas
            id="cpu-spark"
            phx-hook="Spark"
            data-value={fmt(@metrics.cpu.utilization, 1)}
            data-ts={@metrics.timestamp}
            data-color="#0070f3"
            width="600"
            height="52"
          ></canvas>
        </div>

        <div class="card span-2">
          <div class="label">System Memory</div>
          <div>
            <span class="value">{fmt(@metrics.memory.percent, 1)}<span class="unit">%</span></span>
          </div>
          <div class="meta">
            {fmt_bytes(@metrics.memory.used)} / {fmt_bytes(@metrics.memory.total)} used
          </div>
          <div class="bar">
            <span style={"width:#{min(100, @metrics.memory.percent)}%"}></span>
          </div>
          <canvas
            id="mem-spark"
            phx-hook="Spark"
            data-value={fmt(@metrics.memory.percent, 1)}
            data-ts={@metrics.timestamp}
            data-color="#00b8a3"
            width="600"
            height="52"
          ></canvas>
        </div>

        <div class="card">
          <div class="label">Load Average</div>
          <div><span class="value">{fmt(@metrics.cpu.load_avg_1m, 2)}</span></div>
          <div class="meta">
            1m {fmt(@metrics.cpu.load_avg_1m, 2)} · 5m {fmt(@metrics.cpu.load_avg_5m, 2)}
          </div>
        </div>

        <div class="card">
          <div class="label">BEAM Processes</div>
          <div><span class="value">{fmt_int(@metrics.beam.process_count)}</span></div>
          <div class="meta">of {fmt_int(@metrics.beam.process_limit)} limit</div>
        </div>

        <div class="card">
          <div class="label">BEAM Memory</div>
          <div><span class="value">{fmt_bytes(@metrics.beam.memory_total)}</span></div>
          <div class="meta">VM heap total</div>
        </div>

        <div class="card">
          <div class="label">Uptime</div>
          <div><span class="value">{fmt_uptime(@metrics.beam.uptime_ms)}</span></div>
          <div class="meta">since boot</div>
        </div>
      </div>

      <footer>Streaming once per second over <code>Phoenix LiveView</code></footer>
    </div>
    """
  end

  defp fmt(number, decimals) do
    :erlang.float_to_binary(number / 1, decimals: decimals)
  end

  defp fmt_int(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  defp fmt_bytes(bytes) do
    {value, unit} = scale_bytes(bytes / 1, ~w(B KB MB GB TB))
    decimals = if value >= 100 or unit == "B", do: 0, else: 1
    "#{:erlang.float_to_binary(value, decimals: decimals)} #{unit}"
  end

  defp scale_bytes(value, [unit]), do: {value, unit}
  defp scale_bytes(value, [unit | _rest]) when value < 1024, do: {value, unit}
  defp scale_bytes(value, [_unit | rest]), do: scale_bytes(value / 1024, rest)

  defp fmt_uptime(ms) do
    seconds = div(ms, 1000)
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m #{secs}s"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end
end
