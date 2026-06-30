defmodule MetricsDemoWeb.DashboardLiveTest do
  use MetricsDemoWeb.ConnCase, async: false

  alias MetricsDemoWeb.DashboardLive

  test "the live dashboard mounts and renders", %{conn: conn} do
    {:ok, _live, html} = live(conn, "/?boot=1")

    assert html =~ "Live System Metrics"
    assert html =~ "CPU Utilization"
  end

  test "handle_info/2 replaces the metrics assign on a broadcast" do
    socket = Phoenix.Component.assign(%Phoenix.LiveView.Socket{}, metrics: %{marker: :stale})

    assert {:noreply, updated} = DashboardLive.handle_info({:metrics, %{marker: :fresh}}, socket)
    assert updated.assigns.metrics == %{marker: :fresh}
  end

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert response(conn, 200) == "ok"
  end

  test "unknown route returns 404", %{conn: conn} do
    assert get(conn, "/nope").status == 404
  end
end
