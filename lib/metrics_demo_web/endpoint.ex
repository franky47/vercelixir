defmodule MetricsDemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :metrics_demo

  @session_options [
    store: :cookie,
    key: "_metrics_demo_key",
    signing_salt: "mDsSess01",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :metrics_demo,
    gzip: false,
    only: MetricsDemoWeb.static_paths()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MetricsDemoWeb.Router
end
