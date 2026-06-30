defmodule MetricsDemo.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test

  @opts MetricsDemo.Router.init([])

  test "GET / serves the dashboard" do
    conn = MetricsDemo.Router.call(conn(:get, "/"), @opts)

    assert conn.status == 200
    assert conn.resp_body =~ "Live System Metrics"
  end

  test "GET /healthz returns ok" do
    conn = MetricsDemo.Router.call(conn(:get, "/healthz"), @opts)

    assert conn.status == 200
    assert conn.resp_body == "ok"
  end

  test "unknown route returns 404" do
    conn = MetricsDemo.Router.call(conn(:get, "/nope"), @opts)

    assert conn.status == 404
  end
end
