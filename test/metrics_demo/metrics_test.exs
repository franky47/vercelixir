defmodule MetricsDemo.MetricsTest do
  use ExUnit.Case, async: true

  alias MetricsDemo.Metrics

  test "collect/0 returns a JSON-encodable snapshot" do
    metrics = Metrics.collect()

    assert {:ok, json} = Jason.encode(metrics)
    assert is_binary(json)
  end

  test "cpu section reports sane shape" do
    %{cpu: cpu} = Metrics.collect()

    assert cpu.cores > 0
    assert cpu.utilization >= 0.0 and cpu.utilization <= 100.0
    assert cpu.run_queue >= 0
    assert is_float(cpu.load_avg_1m)
  end

  test "memory percent stays within bounds" do
    %{memory: memory} = Metrics.collect()

    assert memory.total >= 0
    assert memory.used >= 0
    assert memory.percent >= 0.0 and memory.percent <= 100.0
  end

  test "beam section exposes runtime counters" do
    %{beam: beam} = Metrics.collect()

    assert beam.process_count > 0
    assert beam.process_count <= beam.process_limit
    assert beam.memory_total > 0
    assert beam.uptime_ms >= 0
  end
end
