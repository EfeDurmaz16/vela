defmodule VelaWeb.Api.V1.RepoActionsTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Repo}
  alias Vela.Forge.Repository
  alias Vela.Outbox.OutboxEvent
  alias VelaWeb.Api.V1.RepoActions

  test "import_github_repo rejects unsupported providers" do
    %{conn: conn} = fixture!("unsupported")

    conn =
      RepoActions.import_github_repo(conn, %{
        "owner" => "vela",
        "repo" => "core",
        "provider" => "gitlab"
      })

    assert json_response(conn, 422) == %{"error" => %{"code" => "unsupported_provider"}}
  end

  test "import_github_repo creates a placeholder repository and queues import evidence" do
    %{actor: actor, conn: conn, organization: organization} = fixture!("create")

    response =
      conn
      |> RepoActions.import_github_repo(%{"owner" => "vela", "repo" => "core"})
      |> json_response(202)

    assert %{
             "data" => %{
               "repository" => %{
                 "id" => repository_id,
                 "full_name" => "vela/core",
                 "import_status" => "pending",
                 "provider" => "github"
               },
               "job" => %{"kind" => "repo_import", "status" => "queued"}
             }
           } = response

    repository = Repo.get!(Repository, repository_id)
    assert repository.organization_id == organization.id
    assert repository.slug == "core"

    assert [%{event_type: "repo.import_queued", actor_id: actor_id, resource_id: ^repository_id}] =
             Evidence.list_repository_events(repository.id, 5)

    assert actor_id == actor.id

    assert [%OutboxEvent{event_type: "repo.import_queued", repository_id: ^repository_id}] =
             OutboxEvent |> Repo.all()
  end

  test "import_github_repo reuses an existing placeholder for the same slug" do
    %{conn: conn, organization: organization} = fixture!("reuse")

    first =
      conn
      |> RepoActions.import_github_repo(%{"owner" => "vela", "repo" => "core"})
      |> json_response(202)

    second =
      conn
      |> Phoenix.ConnTest.recycle()
      |> assign_current(organization, conn.assigns.current_actor)
      |> RepoActions.import_github_repo(%{"owner" => "vela-renamed", "repo" => "core"})
      |> json_response(202)

    repository_id = first["data"]["repository"]["id"]
    assert second["data"]["repository"]["id"] == repository_id
    assert Repo.get!(Repository, repository_id).full_name == "vela-renamed/core"

    repositories =
      Repository
      |> Repo.all()
      |> Enum.filter(&(&1.organization_id == organization.id and &1.slug == "core"))

    assert length(repositories) == 1
  end

  defp fixture!(suffix) do
    {:ok, organization} =
      Accounts.create_organization(%{
        name: "Repo Action #{suffix}",
        slug: "repo-action-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: organization.id,
        type: "human",
        display_name: "Repo Actor #{suffix}",
        trust_level: "trusted"
      })

    conn =
      Plug.Test.conn(:post, "/api/v1/repos/import")
      |> assign_current(organization, actor)

    %{actor: actor, conn: conn, organization: organization}
  end

  defp assign_current(conn, organization, actor) do
    conn
    |> Plug.Conn.assign(:current_organization, organization)
    |> Plug.Conn.assign(:current_actor, actor)
  end
end
