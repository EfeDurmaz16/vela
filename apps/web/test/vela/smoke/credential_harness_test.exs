defmodule Vela.Smoke.CredentialHarnessTest do
  use ExUnit.Case, async: true

  alias Vela.Smoke.CredentialHarness

  test "skips every provider when required configuration is missing" do
    assert [
             %{provider: :workos, status: :skip},
             %{provider: :github, status: :skip},
             %{provider: :s3, status: :skip},
             %{provider: :webhooks, status: :skip}
           ] =
             CredentialHarness.run(
               config: fn
                 :workos -> []
                 :github -> []
                 :object_store -> []
                 :webhooks -> []
               end
             )
  end

  test "passes configured providers through injected transports without mutating S3" do
    workos_transport = fn req ->
      assert req.method == :get
      assert req.url.path == "/user_management/sessions/session_smoke"
      assert {"authorization", "Bearer sk_test"} in req.headers

      {:ok, %{status: 200, body: %{"id" => "session_smoke"}}}
    end

    github_transport = fn req ->
      assert req.method == :get
      assert req.url.path == "/repos/vela/core"
      assert {"authorization", "Bearer ghp_test"} in req.headers

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
    end

    s3_transport = fn req ->
      assert req.method == :get
      assert req.url.path == "/vela-artifacts/smoke/readiness.txt"
      assert Enum.any?(req.headers, fn {key, _} -> key == "authorization" end)

      {:ok, %{status: 200, body: "ok"}}
    end

    assert [
             %{provider: :workos, status: :pass},
             %{provider: :github, status: :pass},
             %{provider: :s3, status: :pass},
             %{provider: :webhooks, status: :pass}
           ] =
             CredentialHarness.run(
               config: &configured_config/1,
               transports: %{
                 workos: workos_transport,
                 github: github_transport,
                 s3: s3_transport
               }
             )
  end

  test "marks configured remote check failures as failures" do
    results =
      CredentialHarness.run(
        checks: [:github],
        config: fn :github ->
          [token: "ghp_bad", smoke_owner: "vela", smoke_repo: "core"]
        end,
        transports: %{
          github: fn _req -> {:ok, %{status: 401, body: %{"message" => "Bad credentials"}}} end
        }
      )

    assert [%{provider: :github, status: :fail, reason: {:github_error, 401, _}}] = results
    assert CredentialHarness.exit_status(results) == 1
  end

  test "does not write S3 smoke objects even when a safe prefix is configured" do
    test_pid = self()

    s3_transport = fn req ->
      send(test_pid, {:s3_method, req.method})
      {:ok, %{status: 200, body: "ok"}}
    end

    results =
      CredentialHarness.run(
        checks: [:s3],
        config: fn :object_store ->
          [
            endpoint: "https://s3.test",
            bucket: "vela-artifacts",
            region: "us-east-1",
            access_key_id: "AKIA_TEST",
            secret_access_key: "secret",
            smoke_key: "smoke/existing.txt",
            smoke_safe_prefix: "smoke/"
          ]
        end,
        transports: %{s3: s3_transport}
      )

    assert [%{provider: :s3, status: :pass}] = results
    assert_received {:s3_method, :get}
    refute_received {:s3_method, :put}
  end

  test "formats results as stable structured lines" do
    results = [
      %{provider: :workos, status: :pass, message: "session verified"},
      %{provider: :github, status: :skip, message: "missing GITHUB_TOKEN"},
      %{provider: :s3, status: :fail, reason: :timeout, message: "credential check failed"}
    ]

    assert CredentialHarness.format_results(results) == [
             "PASS workos session verified",
             "SKIP github missing GITHUB_TOKEN",
             "FAIL s3 credential check failed: :timeout"
           ]
  end

  defp configured_config(:workos),
    do: [api_key: "sk_test", client_id: "client_123", smoke_session_id: "session_smoke"]

  defp configured_config(:github),
    do: [token: "ghp_test", smoke_owner: "vela", smoke_repo: "core"]

  defp configured_config(:object_store),
    do: [
      endpoint: "https://s3.test",
      bucket: "vela-artifacts",
      region: "us-east-1",
      access_key_id: "AKIA_TEST",
      secret_access_key: "secret",
      smoke_key: "smoke/readiness.txt"
    ]

  defp configured_config(:webhooks),
    do: [default_secret: "whsec_test", secrets: %{"github" => "whsec_github"}]
end
