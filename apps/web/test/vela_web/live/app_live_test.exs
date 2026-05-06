defmodule VelaWeb.AppLiveTest do
  use VelaWeb.ConnCase

  alias Vela.{Accounts, Agents, Evidence, Forge, Merge}

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
    assert html =~ "Import GitHub Repository"
    assert html =~ "Queue Import"

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

  test "PR cockpit renders blocking findings for risky pull requests", %{conn: conn} do
    pr =
      Forge.active_pull_requests()
      |> Enum.find(&(&1.title == "Refactor auth token validation"))

    {:ok, _view, html} =
      live(conn, "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}")

    assert html =~ pr.title
    assert html =~ "block"
    assert html =~ "missing negative-path tests"
    assert html =~ "modifies auth and billing permissions together"
    assert html =~ "agent exceeded path scope"
    assert html =~ "Status blocked"
  end

  test "PR cockpit renders unknown readiness and missing merge candidate states", %{conn: conn} do
    [seed_pr | _] = Forge.active_pull_requests()

    {:ok, org} =
      Accounts.create_organization(%{
        name: "Unknown Readiness Org",
        slug: "unknown-readiness-#{System.unique_integer([:positive])}"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "unscored-core",
        slug: "unscored-core",
        visibility: "private",
        default_branch: "main",
        health_status: "degraded",
        risk_level: "critical",
        repo_cell_id: nil
      })

    {:ok, pr} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: seed_pr.author_actor.id,
        title: "Unscored auth boundary change",
        description: "Pull request without analysis metadata.",
        source_branch: "agent/unscored-auth-boundary",
        target_branch: "main",
        head_sha: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        base_sha: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        status: "open",
        intent: "Exercise unknown readiness rendering.",
        behavioral_summary: "No analysis has completed for this change yet.",
        risk_level: "critical"
      })

    {:ok, _view, html} = live(conn, "/repos/#{org.slug}/#{repo.slug}/pulls/#{pr.id}")

    assert html =~ "Unscored auth boundary change"
    assert html =~ "unknown"
    assert html =~ "Run analysis before treating this pull request as queue-ready."
    assert html =~ "Human review required"
    assert html =~ "No merge candidate"
    assert html =~ "Not generated"
  end

  test "PR comment form validates input and records review evidence", %{conn: conn} do
    [pr | _] = Forge.active_pull_requests()

    {:ok, view, _html} =
      live(conn, "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}")

    invalid_html =
      view
      |> form("#pr-comment-form", comment: %{body: ""})
      |> render_submit()

    assert invalid_html =~ "Comment body is required."

    body = "Reviewed queue readiness #{System.unique_integer([:positive])}"

    html =
      view
      |> form("#pr-comment-form",
        comment: %{body: "  #{body}  ", publish_to_github: "true"}
      )
      |> render_submit()

    assert html =~ body

    updated =
      Forge.get_pull_request_for_route!(
        pr.repository.organization.slug,
        pr.repository.slug,
        pr.id
      )

    assert Enum.any?(updated.reviews, &(&1.status == "comment" and &1.summary == body))

    assert [
             %{
               event_type: "pr.updated",
               resource_id: pr_id,
               payload: %{
                 "action" => "review_comment_created",
                 "publish_to_github" => true
               }
             }
             | _
           ] =
             pr.repository.id
             |> Evidence.list_repository_events(20)
             |> Enum.filter(&(&1.resource_id == pr.id and &1.event_type == "pr.updated"))

    assert pr_id == pr.id
  end

  test "merge queue button renders queued and gate failure states", %{conn: conn} do
    {ship_pr, ship_view} = open_pr(conn, "Add agent spending policy enforcement")

    ship_html =
      ship_view
      |> form("#merge-queue-form")
      |> render_submit()

    assert ship_html =~ "Status queued"

    assert %{status: "queued", queue_position: 1} =
             Vela.Repo.get!(Merge.MergeCandidate, ship_pr.merge_candidate_id)

    {_missing_approval_pr, missing_approval_view} =
      open_pr(conn, "Refactor auth token validation")

    missing_approval_html =
      missing_approval_view
      |> form("#merge-queue-form")
      |> render_submit()

    assert missing_approval_html =~ "Missing approving review."

    {_blocking_pr, blocking_view} = open_pr(conn, "Queue blocking review example")

    blocking_html =
      blocking_view
      |> form("#merge-queue-form")
      |> render_submit()

    assert blocking_html =~ "Blocking review must be resolved."

    {stale_pr, stale_view} = open_pr(conn, "Queue stale base branch example")

    {:ok, _check} =
      Forge.upsert_check_run(stale_pr.repository_id, stale_pr.id, %{
        provider: "github",
        external_id: "stale-check-#{System.unique_integer([:positive])}",
        name: "test",
        status: "completed",
        conclusion: "success"
      })

    stale_html =
      stale_view
      |> form("#merge-queue-form")
      |> render_submit()

    assert stale_html =~ "Base branch moved; refresh the pull request."
  end

  test "PR cockpit renders changed files, renames, deletions and security markers", %{conn: conn} do
    pr =
      Forge.active_pull_requests(10)
      |> Enum.find(&(&1.title == "Refactor auth token validation"))

    {:ok, _modified} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "apps/web/lib/vela/auth/token.ex",
        previous_path: nil,
        status: "modified",
        blob_sha: "abc123def4567890",
        additions: 18,
        deletions: 4,
        changes: 22
      })

    {:ok, _renamed} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "apps/web/lib/vela/auth/new_token.ex",
        previous_path: "apps/web/lib/vela/auth/old_token.ex",
        status: "renamed",
        blob_sha: "def456abc1237890",
        additions: 4,
        deletions: 1,
        changes: 5
      })

    {:ok, _removed} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "apps/web/lib/vela/auth/legacy_secret.ex",
        previous_path: nil,
        status: "removed",
        blob_sha: nil,
        additions: 0,
        deletions: 8,
        changes: 8
      })

    {:ok, _view, html} =
      live(conn, "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}")

    assert html =~ "Changed Files"
    assert html =~ "apps/web/lib/vela/auth/token.ex"
    assert html =~ "apps/web/lib/vela/auth/new_token.ex"
    assert html =~ "renamed from apps/web/lib/vela/auth/old_token.ex"
    assert html =~ "apps/web/lib/vela/auth/legacy_secret.ex"
    assert html =~ "removed"
    assert html =~ "+18"
    assert html =~ "-8"
    assert html =~ "blob abc123def456"
    assert html =~ "security-sensitive"
  end

  test "agents launches evidence and settings render", %{conn: conn} do
    [agent | _] = Agents.list_agent_profiles()

    for path <- [~p"/agents", "/agents/#{agent.id}", ~p"/launches", ~p"/evidence", ~p"/settings"] do
      {:ok, _view, html} = live(conn, path)
      assert html =~ "Vela"
    end
  end

  test "evidence ledger renders populated and empty states", %{conn: conn} do
    {:ok, _view, populated_html} = live(conn, ~p"/evidence")

    assert populated_html =~ "Evidence Ledger"
    assert populated_html =~ "Chain healthy"
    assert populated_html =~ "hash"
    assert populated_html =~ "prev"

    Vela.Repo.delete_all(Vela.Evidence.TamperAlarm)
    Vela.Repo.delete_all(Vela.Evidence.EvidenceEvent)

    {:ok, _view, empty_html} = live(conn, ~p"/evidence")

    assert empty_html =~ "Evidence Ledger"
    assert empty_html =~ "No evidence events yet"
    assert empty_html =~ "Append the first trusted action"
  end

  test "evidence ledger renders healthy empty and tampered verifier states", %{conn: conn} do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Verifier Org",
        slug: "verifier-org-#{System.unique_integer([:positive])}"
      })

    {:ok, actor} =
      Vela.Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Verifier Actor",
        trust_level: "trusted"
      })

    {:ok, empty_repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "empty-verifier",
        slug: "empty-verifier",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, tampered_repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "tampered-verifier",
        slug: "tampered-verifier",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, event} =
      Evidence.append_event(%{
        organization_id: org.id,
        repository_id: tampered_repo.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        resource_id: tampered_repo.id,
        payload: %{repo: "tampered-verifier"}
      })

    event
    |> Ecto.Changeset.change(payload: %{"repo" => "changed-after-append"})
    |> Vela.Repo.update!()

    {:ok, _view, html} = live(conn, ~p"/evidence")

    assert html =~ empty_repo.name
    assert html =~ "No evidence"
    assert html =~ tampered_repo.name
    assert html =~ "Chain tampered"
    assert html =~ "payload_hash_mismatch"
  end

  test "repository import form validates input and queues import work", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/repos")

    invalid_html =
      view
      |> form("#repo-import-form", import: %{owner: "", repo: ""})
      |> render_submit()

    assert invalid_html =~ "Owner and repository are required."

    view
    |> form("#repo-import-form",
      import: %{owner: "  sardis-labs  ", repo: "  Imported-Core  "}
    )
    |> render_submit()

    flash = assert_redirect(view, "/repos/sardis-labs/imported-core")
    assert flash["info"] == "Repository import queued for sardis-labs/Imported-Core."

    org = Accounts.get_organization_by_slug!("sardis-labs")
    repo = Forge.get_repository_by_slug_for_org(org.id, "imported-core")

    assert repo.name == "Imported-Core"
    assert repo.full_name == "sardis-labs/Imported-Core"
    assert repo.import_status == "pending"

    assert %Oban.Job{args: %{"kind" => "repo_import", "repository_id" => repo_id}} =
             Oban.Job
             |> Vela.Repo.all()
             |> Enum.find(&(&1.args["repository_id"] == repo.id))

    assert repo_id == repo.id

    assert [%{event_type: "repo.import_queued", resource_id: ^repo_id}] =
             Evidence.list_repository_events(repo.id, 5)
  end

  defp open_pr(conn, title) do
    pr =
      Forge.active_pull_requests(10)
      |> Enum.find(&(&1.title == title))

    {:ok, view, _html} =
      live(conn, "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}")

    {pr, view}
  end
end
