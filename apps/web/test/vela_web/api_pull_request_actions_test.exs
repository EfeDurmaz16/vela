defmodule VelaWeb.Api.V1.PullRequestActionsTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Forge, Repo}
  alias Vela.Outbox.OutboxEvent
  alias VelaWeb.Api.V1.PullRequestActions

  test "create_comment records a local review, evidence, and outbox event" do
    %{conn: conn, organization: organization, pull_request: pull_request} = pr_fixture!("local")

    response =
      conn
      |> PullRequestActions.create_comment(pull_request, "Looks bounded.", %{})
      |> json_response(201)

    assert %{"data" => %{"status" => "comment", "summary" => "Looks bounded.", "github" => nil}} =
             response

    assert [%{event_type: "pr.comment.created", organization_id: org_id, payload: payload}] =
             Evidence.list_repository_events(pull_request.repository_id, 5)

    assert org_id == organization.id
    assert payload["pull_request_id"] == pull_request.id

    assert [%OutboxEvent{event_type: "pr.comment.created", payload: outbox_payload}] =
             OutboxEvent |> Repo.all()

    assert outbox_payload["pull_request_id"] == pull_request.id
  end

  test "create_comment can publish the comment to GitHub" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn req ->
        assert req.method == :post
        assert req.url.path == "/repos/vela/core/issues/17/comments"
        assert req.body == %{"body" => "Vela says ship."}

        {:ok,
         %{
           status: 201,
           body: %{
             "id" => 999,
             "html_url" => "https://github.test/comment",
             "body" => "Vela says ship."
           }
         }}
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :github, previous),
        else: Application.delete_env(:vela, :github)
    end)

    %{conn: conn, pull_request: pull_request} = pr_fixture!("github")

    response =
      conn
      |> PullRequestActions.create_comment(pull_request, "Vela says ship.", %{
        "publish_to_github" => true
      })
      |> json_response(201)

    assert %{
             "data" => %{
               "github" => %{
                 "external_id" => 999,
                 "html_url" => "https://github.test/comment"
               }
             }
           } = response
  end

  defp pr_fixture!(suffix) do
    {:ok, organization} =
      Accounts.create_organization(%{
        name: "PR Action #{suffix}",
        slug: "pr-action-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: organization.id,
        type: "human",
        display_name: "PR Actor #{suffix}",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: organization.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low",
        provider: "github",
        full_name: "vela/core",
        import_status: "imported"
      })

    {:ok, pull_request} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: actor.id,
        title: "Change",
        source_branch: "feature",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review",
        provider: "github",
        external_number: 17,
        html_url: "https://github.com/vela/core/pull/17"
      })

    pull_request = %{pull_request | repository: repo}

    conn =
      Plug.Test.conn(:post, "/api/v1/pull-requests/#{pull_request.id}/comments")
      |> Plug.Conn.assign(:current_organization, organization)
      |> Plug.Conn.assign(:current_actor, actor)

    %{conn: conn, organization: organization, pull_request: pull_request}
  end
end
