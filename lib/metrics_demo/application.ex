defmodule MetricsDemo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: MetricsDemo.PubSub},
      MetricsDemo.Collector,
      MetricsDemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MetricsDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MetricsDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
