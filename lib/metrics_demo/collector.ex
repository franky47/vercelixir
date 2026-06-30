defmodule MetricsDemo.Collector do
  @moduledoc """
  Samples metrics once per second and broadcasts the encoded payload to every
  subscribed socket via a `:pg` process group.

  Centralising the cadence keeps `:cpu_sup.util/0` accurate (it reports usage
  since its previous call) and encodes each sample only once, regardless of how
  many clients are connected.
  """

  use GenServer

  @scope MetricsDemo.PG
  @group :metrics
  @interval 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe the calling process to broadcasts of `{:metrics, json}`."
  @spec subscribe() :: :ok
  def subscribe do
    :pg.join(@scope, @group, self())
  end

  @doc "Return the most recently sampled payload as a JSON string."
  @spec latest() :: String.t()
  def latest do
    GenServer.call(__MODULE__, :latest)
  end

  @impl true
  def init(_opts) do
    schedule()
    {:ok, %{latest: sample()}}
  end

  @impl true
  def handle_call(:latest, _from, state) do
    {:reply, state.latest, state}
  end

  @impl true
  def handle_info(:sample, _state) do
    schedule()
    payload = sample()
    broadcast(payload)
    {:noreply, %{latest: payload}}
  end

  defp sample do
    MetricsDemo.Metrics.collect() |> Jason.encode!()
  end

  defp broadcast(payload) do
    for pid <- :pg.get_members(@scope, @group) do
      send(pid, {:metrics, payload})
    end
  end

  defp schedule do
    Process.send_after(self(), :sample, @interval)
  end
end
