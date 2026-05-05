defmodule VelaWeb.RepositoryCrudTest do
  use VelaWeb.ConnCase, async: true

  alias Vela.{Accounts, Actors, Forge, Repo}
  alias VelaWeb.Plugs.ApiAuth

  test "authenticated users can create a repository in their organization", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "CRUD Org", slug: "crud-org"})
    session = auth_session_for_org!(org, "create")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/repos", %{
        name: "Core",
        slug: "core",
        visibility: "private",
        default_branch: "main"
      })
      |> json_response(201)

    assert %{"data" => %{"id" => id, "slug" => "core", "organization_id" => org_id}} = response
    assert org_id == org.id
    assert Repo.get!(Vela.Forge.Repository, id).organization_id == org.id
  end

  test "authenticated users can read and update repositories in their organization", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "CRUD Update Org", slug: "crud-update-org"})
    session = auth_session_for_org!(org, "update")

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "Core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "unknown",
        risk_level: "medium"
      })

    show =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> get(~p"/api/v1/repos/#{repo.id}")
      |> json_response(200)

    assert %{"data" => %{"id" => id, "slug" => "core"}} = show
    assert id == repo.id

    updated =
      conn
      |> recycle()
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put(~p"/api/v1/repos/#{repo.id}", %{risk_level: "low", health_status: "healthy"})
      |> json_response(200)

    assert %{"data" => %{"risk_level" => "low", "health_status" => "healthy"}} = updated
  end

  test "authenticated users cannot access repositories outside their organization", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "CRUD Tenant A", slug: "crud-tenant-a"})

    {:ok, other_org} =
      Accounts.create_organization(%{name: "CRUD Tenant B", slug: "crud-tenant-b"})

    session = auth_session_for_org!(org, "tenant-a")

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: other_org.id,
        name: "Other",
        slug: "other",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> get(~p"/api/v1/repos/#{repo.id}")
      |> json_response(404)

    assert %{"error" => %{"code" => "repo_not_found"}} = response
  end

  test "authenticated users can delete repositories in their organization", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "CRUD Delete Org", slug: "crud-delete-org"})
    session = auth_session_for_org!(org, "delete")

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "Delete Me",
        slug: "delete-me",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    conn
    |> init_test_session(%{ApiAuth.session_key() => session})
    |> delete(~p"/api/v1/repos/#{repo.id}")
    |> response(204)

    refute Repo.get(Vela.Forge.Repository, repo.id)
  end

  test "authenticated users can start a GitHub import from owner and repo", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "GH Import Org", slug: "gh-import-org"})
    session = auth_session_for_org!(org, "github-import")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/repos/import", %{provider: "github", owner: "vela", repo: "core"})
      |> json_response(202)

    assert %{
             "data" => %{
               "repository" => %{
                 "id" => repo_id,
                 "provider" => "github",
                 "full_name" => "vela/core",
                 "import_status" => "pending"
               },
               "job" => %{"kind" => "repo_import", "status" => "queued"}
             }
           } = response

    repository = Repo.get!(Vela.Forge.Repository, repo_id)
    assert repository.organization_id == org.id
    assert repository.slug == "core"
    assert repository.health_status == "unknown"

    assert [%{event_type: "repo.import_queued", resource_id: ^repo_id}] =
             Vela.Evidence.list_repository_events(repo_id, 5)
  end

  test "GitHub import reuses an existing repository placeholder for the same slug", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "GH Existing Org", slug: "gh-existing-org"})
    session = auth_session_for_org!(org, "github-existing")

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "unknown",
        risk_level: "medium"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/repos/import", %{provider: "github", owner: "vela", repo: "core"})
      |> json_response(202)

    assert %{"data" => %{"repository" => %{"id" => id}}} = response
    assert id == repo.id
    assert Repo.get!(Vela.Forge.Repository, repo.id).import_status == "pending"
  end

  test "authenticated users can inspect repository readiness", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Readiness Org", slug: "readiness-org"})
    session = auth_session_for_org!(org, "readiness")

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Reviewer",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low",
        import_status: "imported"
      })

    {:ok, _signal} =
      Forge.create_repository_trust_signal(%{
        organization_id: org.id,
        repository_id: repo.id,
        source: "github",
        signal_type: "branch_protection",
        score: 92,
        confidence: "high"
      })

    {:ok, _pr} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: actor.id,
        title: "Change",
        source_branch: "feature",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> get(~p"/api/v1/repos/#{repo.id}/readiness")
      |> json_response(200)

    assert %{
             "data" => %{
               "repository_id" => repo_id,
               "health_status" => "healthy",
               "risk_level" => "low",
               "import_status" => "imported",
               "open_pull_requests" => 1,
               "trust" => %{"score" => 92, "confidence" => "high"}
             }
           } = response

    assert repo_id == repo.id
  end

  defp auth_session_for_org!(org, suffix) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "repo-crud-#{suffix}@example.com",
        name: "Repo CRUD #{suffix}",
        workos_user_id: "workos_repo_crud_#{suffix}"
      })

    {:ok, membership} =
      Accounts.create_membership(%{user_id: user.id, organization_id: org.id, role: "admin"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        created_by_user_id: user.id,
        type: "human",
        display_name: user.name,
        trust_level: "trusted",
        external_ref: "workos:#{user.workos_user_id}"
      })

    %{
      "user_id" => user.id,
      "organization_id" => org.id,
      "membership_id" => membership.id,
      "actor_id" => actor.id
    }
  end
end
