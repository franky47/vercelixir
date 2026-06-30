defmodule MetricsDemoWeb.Format do
  @moduledoc "Pure helpers for rendering metric values as display strings."

  @spec decimal(number(), non_neg_integer()) :: String.t()
  def decimal(number, places) do
    :erlang.float_to_binary(number / 1, decimals: places)
  end

  @spec integer(integer()) :: String.t()
  def integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  @spec bytes(number()) :: String.t()
  def bytes(count) do
    {value, unit} = scale(count / 1, ~w(B KB MB GB TB))
    places = if value >= 100 or unit == "B", do: 0, else: 1
    "#{:erlang.float_to_binary(value, decimals: places)} #{unit}"
  end

  defp scale(value, [unit]), do: {value, unit}
  defp scale(value, [unit | _rest]) when value < 1024, do: {value, unit}
  defp scale(value, [_unit | rest]), do: scale(value / 1024, rest)

  @spec uptime(non_neg_integer()) :: String.t()
  def uptime(ms) do
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
