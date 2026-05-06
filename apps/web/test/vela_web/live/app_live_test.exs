defmodule VelaWeb.AppLiveTest do
  use VelaWeb.ConnCase

  alias Vela.{Accounts, Agents, Forge}

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    :ok
  end

  test "home renders Vela trust cockpit", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "GitHub stores code"
    assert html =~ "Add agent spending policy enforcement"
    assert html =~ "Evidence hash chain"
    assert html =~ ~s(href="/repos")
    assert html =~ "Pull Requests"
    assert html =~ "Launches"
    assert html =~ "Agents"
    assert html =~ "Settings"
  end

  test "repositories and repo overview render seeded trust state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/repos")
    assert html =~ "sardis"
    assert html =~ "vela"

    {:ok, _view, repo_html} = live(conn, ~p"/repos/sardis-labs/sardis")
    assert repo_html =~ "Can I trust the current state"
    assert repo_html =~ "cell-us-east-1-demo"
    assert repo_html =~ "Add agent spending policy enforcement"
    assert repo_html =~ "ship"
  end

  test "repository overview renders empty and risky repository states", %{conn: conn} do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Empty Org",
        slug: "empty-org-#{System.unique_integer([:positive])}"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "empty-core",
        slug: "empty-core",
        visibility: "private",
        default_branch: "main",
        health_status: "degraded",
        risk_level: "high",
        repo_cell_id: nil
      })

    {:ok, _view, html} = live(conn, "/repos/#{org.slug}/#{repo.slug}")

    assert html =~ "empty-core"
    assert html =~ "degraded"
    assert html =~ "high"
    assert html =~ "unassigned"
    assert html =~ "Active PRs"
  end

  test "PR cockpit renders score, verdict, provenance and merge placeholders", %{conn: conn} do
    [pr | _] = Forge.active_pull_requests()

    {:ok, _view, html} =
      live(conn, "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}")

    assert html =~ pr.title
    assert html =~ "Launch Readiness"
    assert html =~ "Agent Provenance"
    assert html =~ "Merge Simulation"
    assert html =~ "Raw Code Diff"
  end

  test "agents launches evidence and settings render", %{conn: conn} do
    [agent | _] = Agents.list_agent_profiles()

    for path <- [~p"/agents", "/agents/#{agent.id}", ~p"/launches", ~p"/evidence", ~p"/settings"] do
      {:ok, _view, html} = live(conn, path)
      assert html =~ "Vela"
    end
  end
end
