defmodule MetricsDemo.Application do
  @moduledoc false

  use Application

  @pg_scope MetricsDemo.PG

  @impl true
  def start(_type, _args) do
    children =
      [
        %{id: @pg_scope, start: {:pg, :start_link, [@pg_scope]}},
        MetricsDemo.Collector
      ] ++ server_children()

    opts = [strategy: :one_for_one, name: MetricsDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp server_children do
    if Application.fetch_env!(:metrics_demo, :server) do
      port = Application.fetch_env!(:metrics_demo, :port)
      [{Bandit, plug: MetricsDemo.Router, ip: {0, 0, 0, 0}, port: port}]
    else
      []
    end
  end
end
