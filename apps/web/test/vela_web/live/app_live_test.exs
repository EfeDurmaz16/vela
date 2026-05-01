defmodule VelaWeb.AppLiveTest do
  use VelaWeb.ConnCase

  alias Vela.{Agents, Forge}

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    :ok
  end

  test "home renders Vela trust cockpit", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "GitHub stores code"
    assert html =~ "Add agent spending policy enforcement"
    assert html =~ "Evidence hash chain"
  end

  test "repositories and repo overview render seeded trust state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/repos")
    assert html =~ "sardis"
    assert html =~ "vela"

    {:ok, _view, repo_html} = live(conn, ~p"/repos/sardis-labs/sardis")
    assert repo_html =~ "Can I trust the current state"
    assert repo_html =~ "cell-us-east-1-demo"
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
