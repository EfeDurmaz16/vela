defmodule VelaWeb.Api.V1.ResponseTest do
  use VelaWeb.ConnCase, async: true

  alias Vela.Forge.Repository
  alias VelaWeb.Api.V1.Response

  test "page_size accepts limits from 1 to 100" do
    assert Response.page_size(%{}) == 25
    assert Response.page_size(%{"limit" => "1"}) == 1
    assert Response.page_size(%{"limit" => "100"}) == 100
  end

  test "page_size falls back for invalid limits" do
    assert Response.page_size(%{"limit" => "0"}) == 25
    assert Response.page_size(%{"limit" => "101"}) == 25
    assert Response.page_size(%{"limit" => "not-a-number"}) == 25
  end

  test "serialize drops framework and unloaded association fields" do
    repository = %Repository{
      id: Ecto.UUID.generate(),
      name: "Vela",
      slug: "vela",
      visibility: "private"
    }

    serialized = Response.serialize(repository)

    assert serialized.type == "repository"
    assert serialized.name == "Vela"
    refute Map.has_key?(serialized, :__meta__)
    refute Map.has_key?(serialized, :organization)
  end

  test "validation_error renders map-backed validation details", %{conn: conn} do
    conn = Response.validation_error(conn, %{errors: %{number: ["must be a positive integer"]}})

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"number" => ["must be a positive integer"]}
             }
           }
  end
end
