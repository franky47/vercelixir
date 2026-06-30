defmodule MetricsDemoWeb.Router do
  use MetricsDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
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
end
