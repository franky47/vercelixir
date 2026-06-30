defmodule MetricsDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :metrics_demo,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {MetricsDemo.Application, []},
      extra_applications: [:logger, :os_mon]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:websock_adapter, "~> 0.5"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"}
    ]
  end

  defp releases do
    [
      metrics_demo: [
        include_executables_for: [:unix],
        steps: [:assemble]
      ]
    ]
  end
end
