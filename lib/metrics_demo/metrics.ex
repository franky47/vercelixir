defmodule MetricsDemo.Metrics do
  @moduledoc """
  Snapshots host and BEAM runtime metrics into a JSON-serializable map.

  Host CPU and memory figures come from `:os_mon` (`:cpu_sup`/`:memsup`),
  which is only meaningful when sampled from a single process. The
  `MetricsDemo.Collector` owns that single sampling cadence.
  """

  @spec collect() :: map()
  def collect do
    %{
      timestamp: System.system_time(:millisecond),
      cpu: cpu(),
      memory: memory(),
      beam: beam()
    }
  end

  defp cpu do
    %{
      utilization: utilization(),
      load_avg_1m: load(&:cpu_sup.avg1/0),
      load_avg_5m: load(&:cpu_sup.avg5/0),
      cores: System.schedulers_online(),
      run_queue: :erlang.statistics(:total_run_queue_lengths_all)
    }
  end

  defp utilization do
    case :cpu_sup.util() do
      percent when is_number(percent) -> Float.round(percent / 1, 1)
      _unsupported -> 0.0
    end
  end

  defp load(fun) do
    case fun.() do
      value when is_number(value) -> Float.round(value / 256, 2)
      _unsupported -> 0.0
    end
  end

  defp memory do
    data = :memsup.get_system_memory_data()
    total = Keyword.get(data, :total_memory, 0)
    available = Keyword.get(data, :available_memory) || Keyword.get(data, :free_memory, 0)
    used = max(total - available, 0)

    %{
      total: total,
      used: used,
      available: available,
      percent: percentage(used, total)
    }
  end

  defp beam do
    %{
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      memory_total: :erlang.memory(:total),
      uptime_ms: elem(:erlang.statistics(:wall_clock), 0)
    }
  end

  defp percentage(_used, 0), do: 0.0
  defp percentage(used, total), do: Float.round(used / total * 100, 1)
end
