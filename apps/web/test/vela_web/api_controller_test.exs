defmodule VelaWeb.ApiControllerTest do
  use VelaWeb.ConnCase, async: true

  test "health and v1 collection endpoints return JSON envelopes", %{conn: conn} do
    assert %{"status" => "ok"} = conn |> get(~p"/health") |> json_response(200)

    response =
      conn
      |> get(~p"/api/v1/orgs")
      |> json_response(200)

    assert %{"data" => [], "pagination" => %{"limit" => 25, "returned" => 0}} = response
  end
end
