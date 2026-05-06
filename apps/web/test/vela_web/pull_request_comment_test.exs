defmodule VelaWeb.PullRequestCommentTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Forge}
  alias VelaWeb.Plugs.ApiAuth

  test "authenticated users can create a local PR comment", %{conn: conn} do
    %{org: org, session: session, pull_request: pr} = pr_fixture!("local")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/comments", %{body: "Looks good."})
      |> json_response(201)

    assert %{"data" => %{"status" => "comment", "summary" => "Looks good."}} = response

    assert [%{event_type: "pr.comment.created", organization_id: org_id}] =
             Vela.Evidence.list_repository_events(pr.repository_id, 5)

    assert org_id == org.id
  end

  test "reviewer and maintainer roles can create PR comments", %{conn: conn} do
    for role <- ~w(reviewer maintainer) do
      %{pull_request: pr, session: session} = pr_fixture!("role-#{role}", role)

      response =
        conn
        |> recycle()
        |> init_test_session(%{ApiAuth.session_key() => session})
        |> post(~p"/api/v1/pull-requests/#{pr.id}/comments", %{body: "Role #{role} comment"})
        |> json_response(201)

      assert %{"data" => %{"status" => "comment", "summary" => summary}} = response
      assert summary == "Role #{role} comment"
    end
  end

  test "observer role cannot create PR comments", %{conn: conn} do
    %{pull_request: pr, session: session} = pr_fixture!("observer", "observer")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/comments", %{body: "No mutation"})
      |> json_response(403)

    assert response == %{"error" => %{"code" => "forbidden"}}
    assert Vela.Repo.all(Vela.Forge.Review) == []
  end

  test "authenticated users can publish a PR comment to GitHub", %{conn: conn} do
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

    %{session: session, pull_request: pr} = pr_fixture!("github")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/comments", %{
        body: "Vela says ship.",
        publish_to_github: true
      })
      |> json_response(201)

    assert %{
             "data" => %{
               "status" => "comment",
               "github" => %{"external_id" => 999, "html_url" => "https://github.test/comment"}
             }
           } = response
  end

  test "PR comments reject pull requests outside the authenticated tenant", %{conn: conn} do
    %{session: session} = pr_fixture!("tenant-a")
    %{pull_request: pr} = pr_fixture!("tenant-b")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/comments", %{body: "Nope"})
      |> json_response(404)

    assert %{"error" => %{"code" => "pull_request_not_found"}} = response
  end

  defp pr_fixture!(suffix, role \\ "admin") do
    {:ok, org} =
      Accounts.create_organization(%{name: "PR Comment #{suffix}", slug: "pr-comment-#{suffix}"})

    session = auth_session_for_org!(org, suffix, role)

    {:ok, author} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Author",
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
        provider: "github",
        full_name: "vela/core",
        import_status: "imported"
      })

    {:ok, pr} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: author.id,
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

    %{org: org, repo: repo, pull_request: pr, session: session}
  end

  defp auth_session_for_org!(org, suffix, role) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "pr-comment-#{suffix}@example.com",
        name: "PR Comment #{suffix}",
        workos_user_id: "workos_pr_comment_#{suffix}"
      })

    {:ok, membership} =
      Accounts.create_membership(%{user_id: user.id, organization_id: org.id, role: role})

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
