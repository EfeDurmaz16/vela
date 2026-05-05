defmodule VelaWeb.ApiSurfaceTest do
  use ExUnit.Case, async: true

  test "exposes the v1 backend route contract" do
    routes =
      VelaWeb.Router.__routes__()
      |> Enum.map(&{&1.verb |> to_string() |> String.upcase(), &1.path})

    expected = [
      {"GET", "/api/v1/orgs"},
      {"GET", "/api/v1/repos"},
      {"POST", "/api/v1/repos"},
      {"POST", "/api/v1/repos/import"},
      {"GET", "/api/v1/repos/:id"},
      {"PUT", "/api/v1/repos/:id"},
      {"DELETE", "/api/v1/repos/:id"},
      {"POST", "/api/v1/repos/:id/import"},
      {"POST", "/api/v1/repos/:id/sync-pull-request"},
      {"GET", "/api/v1/repos/:id/readiness"},
      {"GET", "/api/v1/repos/:id/trust"},
      {"GET", "/api/v1/changes"},
      {"GET", "/api/v1/changes/:id/readiness"},
      {"GET", "/api/v1/pull-requests"},
      {"POST", "/api/v1/pull-requests/:id/comments"},
      {"GET", "/api/v1/agents"},
      {"GET", "/api/v1/agents/:id/sessions"},
      {"GET", "/api/v1/agents/:id/policies"},
      {"GET", "/api/v1/analysis-runs"},
      {"GET", "/api/v1/readiness-scores"},
      {"GET", "/api/v1/merge-candidates"},
      {"POST", "/api/v1/merge-candidates/:id/simulate"},
      {"GET", "/api/v1/releases"},
      {"GET", "/api/v1/evidence-events"},
      {"GET", "/api/v1/integrations"},
      {"GET", "/api/v1/service-connections"},
      {"GET", "/api/v1/environments"},
      {"POST", "/api/v1/webhooks/:provider"}
    ]

    assert Enum.all?(expected, &(&1 in routes))
  end
end
