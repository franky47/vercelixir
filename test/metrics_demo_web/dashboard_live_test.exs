defmodule MetricsDemoWeb.DashboardLiveTest do
  use MetricsDemoWeb.ConnCase, async: false

  test "GET / renders the dashboard", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    assert html =~ "Live System Metrics"
    assert html =~ "CPU Utilization"
  end

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert response(conn, 200) == "ok"
  end
end
