defmodule MetricsDemoWeb.Router do
  use MetricsDemoWeb, :router

  @shell_cache_control "public, max-age=0, must-revalidate"
  @shell_cdn_cache_control "max-age=86400, stale-while-revalidate=604800"

  pipeline :browser do
    plug :accepts, ["html"]
    plug :serve_static_shell
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MetricsDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", MetricsDemoWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
  end

  scope "/", MetricsDemoWeb do
    get "/healthz", HealthController, :index
  end

  # `DashboardLive` is mounted at `/` so its session token is bound to that URL.
  # Plain `GET /` short-circuits here with a cookie-less, CDN-cacheable skeleton
  # (instant first paint from Vercel's edge, no cold-container wait). The client
  # then fetches `/?boot=1`, which falls through to the real dead render and
  # carries tokens valid for `/` — so the socket joins with no redirect loop.
  defp serve_static_shell(conn, _opts) do
    conn = fetch_query_params(conn)

    if Map.has_key?(conn.query_params, "boot") do
      conn
    else
      conn
      |> put_resp_header("cache-control", @shell_cache_control)
      |> put_resp_header("vercel-cdn-cache-control", @shell_cdn_cache_control)
      |> put_secure_browser_headers()
      |> put_view(MetricsDemoWeb.PageHTML)
      |> put_format(:html)
      |> render(:shell, layout: false)
      |> halt()
    end
  end
end
