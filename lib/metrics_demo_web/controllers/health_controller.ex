defmodule MetricsDemoWeb.HealthController do
  use MetricsDemoWeb, :controller

  def index(conn, _params) do
    text(conn, "ok")
  end
end
