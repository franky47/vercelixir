defmodule MetricsDemo.Router do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_file(conn, 200, index_path())
  end

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(MetricsDemo.MetricsSocket, [], [])
    |> halt()
  end

  get "/healthz" do
    send_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp index_path do
    Application.app_dir(:metrics_demo, "priv/static/index.html")
  end
end
