defmodule MetricsDemoWeb.ConnCase do
  @moduledoc """
  Test case for tests that need a connection against the endpoint.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use MetricsDemoWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      @endpoint MetricsDemoWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
