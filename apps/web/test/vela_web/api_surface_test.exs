defmodule VelaWeb.ApiSurfaceTest do
  use ExUnit.Case, async: true

  test "exposes the v1 backend route contract" do
    routes =
      VelaWeb.Router.__routes__()
      |> Enum.map(&{&1.verb |> to_string() |> String.upcase(), &1.path, &1.plug, &1.plug_opts})

    expected = [
      {"GET", "/api/v1/orgs", :orgs},
      {"GET", "/api/v1/repos", :repos},
      {"POST", "/api/v1/repos", :create_repo},
      {"POST", "/api/v1/repos/import", :import_github_repo},
      {"GET", "/api/v1/repos/:id", :show_repo},
      {"PUT", "/api/v1/repos/:id", :update_repo},
      {"DELETE", "/api/v1/repos/:id", :delete_repo},
      {"POST", "/api/v1/repos/:id/import", :import_repo},
      {"POST", "/api/v1/repos/:id/sync-pull-request", :sync_pull_request},
      {"GET", "/api/v1/repos/:id/readiness", :repo_readiness},
      {"GET", "/api/v1/repos/:id/trust", :repo_trust},
      {"GET", "/api/v1/changes", :changes},
      {"GET", "/api/v1/changes/:id/readiness", :change_readiness},
      {"GET", "/api/v1/pull-requests", :pull_requests},
      {"POST", "/api/v1/pull-requests/:id/comments", :create_pr_comment},
      {"POST", "/api/v1/pull-requests/:id/merge", :queue_pr_merge},
      {"GET", "/api/v1/agents", :agents},
      {"GET", "/api/v1/agents/:id/sessions", :agent_sessions},
      {"GET", "/api/v1/agents/:id/policies", :agent_policies},
      {"GET", "/api/v1/analysis-runs", :analysis_runs},
      {"GET", "/api/v1/readiness-scores", :readiness_scores},
      {"GET", "/api/v1/merge-candidates", :merge_candidates},
      {"POST", "/api/v1/merge-candidates/:id/simulate", :simulate_merge},
      {"GET", "/api/v1/releases", :releases},
      {"GET", "/api/v1/evidence-events", :evidence_events},
      {"GET", "/api/v1/integrations", :integrations},
      {"GET", "/api/v1/service-connections", :service_connections},
      {"GET", "/api/v1/environments", :environments},
      {"POST", "/api/v1/webhooks/:provider", :webhook}
    ]

    assert Enum.all?(expected, fn {verb, path, action} ->
             {verb, path, VelaWeb.Api.V1.FoundationController, action} in routes
           end)
  end
end
