defmodule MetricsDemo.Collector do
  @moduledoc """
  Samples metrics once per second and broadcasts the snapshot to every
  subscribed LiveView over `Phoenix.PubSub`.

  Centralising the cadence keeps `:cpu_sup.util/0` accurate (it reports usage
  since its previous call) and samples once per tick regardless of how many
  clients are connected.
  """

  use GenServer

  alias Phoenix.PubSub

  @pubsub MetricsDemo.PubSub
  @topic "metrics"
  @interval 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe the calling process to `{:metrics, map}` broadcasts."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    PubSub.subscribe(@pubsub, @topic)
  end

  @doc "Return the most recently sampled snapshot."
  @spec latest() :: map()
  def latest do
    GenServer.call(__MODULE__, :latest)
  end

  @impl true
  def init(_opts) do
    schedule()
    {:ok, MetricsDemo.Metrics.collect()}
  end

  @impl true
  def handle_call(:latest, _from, metrics) do
    {:reply, metrics, metrics}
  end

  @impl true
  def handle_info(:sample, _state) do
    schedule()
    metrics = MetricsDemo.Metrics.collect()
    :ok = PubSub.broadcast(@pubsub, @topic, {:metrics, metrics})
    {:noreply, metrics}
  end

  defp schedule do
    Process.send_after(self(), :sample, @interval)
  end
end
