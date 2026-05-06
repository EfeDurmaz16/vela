defmodule VelaWeb.ApiCollectionPaginationTest do
  use VelaWeb.ConnCase, async: true

  @collection_paths [
    "/api/v1/orgs",
    "/api/v1/repos",
    "/api/v1/changes",
    "/api/v1/pull-requests",
    "/api/v1/agents",
    "/api/v1/analysis-runs",
    "/api/v1/readiness-scores",
    "/api/v1/merge-candidates",
    "/api/v1/releases",
    "/api/v1/evidence-events",
    "/api/v1/integrations",
    "/api/v1/service-connections",
    "/api/v1/environments"
  ]

  test "public collection endpoints share explicit limit pagination", %{conn: conn} do
    for path <- @collection_paths do
      response =
        conn
        |> get(path <> "?limit=1")
        |> json_response(200)

      assert %{"data" => data, "pagination" => %{"limit" => 1, "returned" => returned}} =
               response

      assert is_list(data)
      assert returned == length(data)
      assert returned <= 1
    end
  end

  test "public collection endpoints share invalid limit fallback", %{conn: conn} do
    for path <- @collection_paths do
      response =
        conn
        |> get(path <> "?limit=not-a-number")
        |> json_response(200)

      assert %{"pagination" => %{"limit" => 25}} = response
    end
  end
end
