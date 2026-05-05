defmodule Vela.ExternalAdaptersTest do
  use ExUnit.Case, async: true

  alias Vela.Auth.WorkOS
  alias Vela.Git.GitHubClient
  alias Vela.Storage.S3ObjectStore

  test "WorkOS builds AuthKit authorization URL and exchanges codes through configured transport" do
    url =
      WorkOS.authorization_url(%{
        client_id: "client_123",
        redirect_uri: "https://vela.test/auth/callback",
        state: "opaque",
        provider: "authkit"
      })

    assert {:ok, %URI{host: "api.workos.com", path: "/user_management/authorize"} = url} = url
    assert String.contains?(URI.decode_query(url.query)["redirect_uri"], "https://vela.test")

    transport = fn req ->
      assert req.method == :post
      assert req.url.path == "/user_management/authenticate"
      assert {"authorization", "Bearer sk_test"} in req.headers

      {:ok,
       %{status: 200, body: %{"user" => %{"id" => "user_123"}, "organization_id" => "org_123"}}}
    end

    assert {:ok, %{"user" => %{"id" => "user_123"}}} =
             WorkOS.exchange_code(%{
               api_key: "sk_test",
               client_id: "client_123",
               code: "code_123",
               transport: transport
             })
  end

  test "GitHub client imports repository metadata and extracts changed paths from compare API" do
    transport = fn req ->
      case req.url.path do
        "/repos/vela/core" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "id" => 42,
               "name" => "core",
               "full_name" => "vela/core",
               "private" => true,
               "default_branch" => "main"
             }
           }}

        "/repos/vela/core/compare/base...head" ->
          {:ok,
           %{
             status: 200,
             body: %{
               "status" => "ahead",
               "ahead_by" => 1,
               "files" => [%{"filename" => "lib/vela.ex"}, %{"filename" => "mix.exs"}]
             }
           }}
      end
    end

    config = %{owner: "vela", repo: "core", token: "ghp_test", transport: transport}

    assert {:ok, %{slug: "core", visibility: "private", external_id: 42}} =
             GitHubClient.import_repository(config)

    assert {:ok, ["lib/vela.ex", "mix.exs"]} =
             GitHubClient.changed_paths(Map.merge(config, %{base: "base", head: "head"}))
  end

  test "GitHub client creates PR issue comments with the REST issue comments endpoint" do
    transport = fn req ->
      assert req.method == :post
      assert req.url.path == "/repos/vela/core/issues/12/comments"
      assert {"authorization", "Bearer ghp_test"} in req.headers
      assert req.body == %{"body" => "Vela readiness: ship"}

      {:ok,
       %{
         status: 201,
         body: %{
           "id" => 123,
           "html_url" => "https://github.com/vela/core/pull/12#issuecomment-123",
           "body" => "Vela readiness: ship"
         }
       }}
    end

    assert {:ok, %{external_id: 123, html_url: html_url, body: "Vela readiness: ship"}} =
             GitHubClient.create_issue_comment(%{
               owner: "vela",
               repo: "core",
               number: 12,
               body: "Vela readiness: ship",
               token: "ghp_test",
               transport: transport
             })

    assert html_url =~ "issuecomment-123"
  end

  test "GitHub client normalizes pull request metadata" do
    transport = fn req ->
      assert req.method == :get
      assert req.url.path == "/repos/vela/core/pulls/17"

      {:ok,
       %{
         status: 200,
         body: %{
           "id" => 987,
           "number" => 17,
           "title" => "Improve sync",
           "body" => "Adds sync",
           "html_url" => "https://github.com/vela/core/pull/17",
           "state" => "open",
           "draft" => false,
           "head" => %{"ref" => "feature/sync", "sha" => "headsha"},
           "base" => %{"ref" => "main", "sha" => "basesha"},
           "user" => %{"login" => "octocat"}
         }
       }}
    end

    assert {:ok,
            %{
              external_id: 987,
              external_number: 17,
              title: "Improve sync",
              status: "ready_for_review",
              source_branch: "feature/sync",
              target_branch: "main",
              head_sha: "headsha",
              base_sha: "basesha",
              html_url: "https://github.com/vela/core/pull/17"
            }} =
             GitHubClient.fetch_pull_request(%{
               owner: "vela",
               repo: "core",
               number: 17,
               token: "ghp_test",
               transport: transport
             })
  end

  test "S3 object store generates SigV4 presigned URLs and signed PUT requests" do
    config = %{
      endpoint: "https://s3.test",
      bucket: "vela-artifacts",
      region: "us-east-1",
      access_key_id: "AKIA_TEST",
      secret_access_key: "secret",
      now: ~U[2026-05-05 15:00:00Z]
    }

    assert {:ok, %URI{} = url} =
             S3ObjectStore.presign_get(Map.merge(config, %{key: "logs/a.txt", expires_in: 300}))

    query = URI.decode_query(url.query)
    assert query["X-Amz-Algorithm"] == "AWS4-HMAC-SHA256"
    assert query["X-Amz-SignedHeaders"] == "host"

    transport = fn req ->
      assert req.method == :put
      assert req.url.path == "/vela-artifacts/logs/a.txt"
      assert Enum.any?(req.headers, fn {key, _} -> key == "authorization" end)
      {:ok, %{status: 200, body: ""}}
    end

    assert {:ok, %{status: 200}} =
             S3ObjectStore.put_object(
               Map.merge(config, %{key: "logs/a.txt", body: "ok", transport: transport})
             )
  end
end
