defmodule MetricsDemoWeb.StaticShellTest do
  use MetricsDemoWeb.ConnCase, async: true

  test "GET / serves the skeleton shell, not the live view", %{conn: conn} do
    conn = get(conn, ~p"/")

    html = html_response(conn, 200)
    assert html =~ "Live System Metrics"
    assert html =~ ~s(id="dash-root")
    refute html =~ "data-phx-main"
    refute html =~ "data-phx-session"
  end

  test "GET / sets no cookie so Vercel's CDN can cache it", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert get_resp_header(conn, "set-cookie") == []
  end

  test "GET / advertises a CDN cache TTL with stale-while-revalidate", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert get_resp_header(conn, "vercel-cdn-cache-control") == [
             "max-age=86400, stale-while-revalidate=604800"
           ]
  end

  test "GET / tells the browser to revalidate while the edge serves the cache", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
  end

  test "GET /?boot=1 falls through to the real, per-user dead render", %{conn: conn} do
    conn = get(conn, "/?boot=1")

    html = html_response(conn, 200)
    assert html =~ "data-phx-main"
    assert html =~ "data-phx-session"

    # The cookie is exactly why this render can't be CDN-cached or shared.
    assert [_ | _] = get_resp_header(conn, "set-cookie")
    assert get_resp_header(conn, "vercel-cdn-cache-control") == []
  end
end
