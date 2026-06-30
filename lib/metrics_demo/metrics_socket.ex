defmodule MetricsDemo.MetricsSocket do
  @moduledoc """
  WebSock handler that streams metric snapshots to a connected browser.

  It pushes the latest sample immediately on connect, then relays every
  broadcast from `MetricsDemo.Collector`.
  """

  @behaviour WebSock

  @impl true
  def init(_opts) do
    MetricsDemo.Collector.subscribe()
    send(self(), :send_latest)
    {:ok, %{}}
  end

  @impl true
  def handle_in(_message, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(:send_latest, state) do
    {:push, {:text, MetricsDemo.Collector.latest()}, state}
  end

  def handle_info({:metrics, payload}, state) do
    {:push, {:text, payload}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state), do: :ok
end
