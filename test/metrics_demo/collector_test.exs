defmodule MetricsDemo.CollectorTest do
  use ExUnit.Case, async: false

  alias MetricsDemo.Collector

  test "latest/0 returns a metrics snapshot" do
    assert %{cpu: _, memory: _, beam: _} = Collector.latest()
  end

  test "broadcasts a snapshot to subscribers each second" do
    :ok = Collector.subscribe()

    assert_receive {:metrics, %{cpu: _, memory: _, beam: _}}, 1_500
  end
end
