defmodule MetricsDemoWeb.FormatTest do
  use ExUnit.Case, async: true

  alias MetricsDemoWeb.Format

  describe "decimal/2" do
    test "rounds to the given places, accepting ints or floats" do
      assert Format.decimal(12.34, 1) == "12.3"
      assert Format.decimal(7, 2) == "7.00"
    end
  end

  describe "integer/1" do
    test "groups thousands with commas" do
      assert Format.integer(123) == "123"
      assert Format.integer(1_000) == "1,000"
      assert Format.integer(1_234_567) == "1,234,567"
    end
  end

  describe "bytes/1" do
    test "scales units and picks decimals at the boundaries" do
      assert Format.bytes(0) == "0 B"
      assert Format.bytes(1_024) == "1.0 KB"
      assert Format.bytes(1_572_864) == "1.5 MB"
      assert Format.bytes(512 * 1024 * 1024) == "512 MB"
    end
  end

  describe "uptime/1" do
    test "formats across the day/hour/minute/second thresholds" do
      assert Format.uptime(59_000) == "59s"
      assert Format.uptime(60_000) == "1m 0s"
      assert Format.uptime(3_600_000) == "1h 0m 0s"
      assert Format.uptime(90_061_000) == "1d 1h 1m"
    end
  end
end
