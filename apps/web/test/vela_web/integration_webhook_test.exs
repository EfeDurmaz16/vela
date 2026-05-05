defmodule VelaWeb.IntegrationWebhookTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Forge, Webhooks}

  setup do
    previous = Application.get_env(:vela, :webhooks)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :webhooks, previous),
        else: Application.delete_env(:vela, :webhooks)
    end)
  end

  test "provider webhook records an evidence event when tenant actor context is supplied", %{
    conn: conn
  } do
    {:ok, org} = Accounts.create_organization(%{name: "Webhook Org", slug: "webhook-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "integration",
        display_name: "Vercel",
        trust_level: "trusted"
      })

    response =
      conn
      |> post(~p"/api/v1/webhooks/vercel", %{
        organization_id: org.id,
        actor_id: actor.id,
        type: "deployment.ready",
        id: "evt_1"
      })
      |> json_response(202)

    assert %{"data" => %{"accepted" => true, "evidence_event_id" => event_id}} = response
    assert Evidence.list_recent_events(1) |> hd() |> Map.fetch!(:id) == event_id
  end

  test "provider webhook verifies configured HMAC signature before recording evidence", %{
    conn: conn
  } do
    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"vercel" => "whsec_test"}
    )

    {:ok, org} = Accounts.create_organization(%{name: "Signed Hook Org", slug: "signed-hook-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "integration",
        display_name: "Vercel",
        trust_level: "trusted"
      })

    timestamp = "1777990000"

    body =
      Jason.encode!(%{
        organization_id: org.id,
        actor_id: actor.id,
        type: "deployment.ready",
        id: "evt_2"
      })

    signature = Webhooks.sign("whsec_test", timestamp, body)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-vela-timestamp", timestamp)
      |> put_req_header("x-vela-signature", signature)
      |> post(~p"/api/v1/webhooks/vercel", body)
      |> json_response(202)

    assert %{"data" => %{"accepted" => true, "evidence_event_id" => event_id}} = response
    assert Evidence.list_recent_events(1) |> hd() |> Map.fetch!(:id) == event_id
  end

  test "provider webhook rejects unsigned payloads when signatures are required", %{conn: conn} do
    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"vercel" => "whsec_test"}
    )

    response =
      conn
      |> post(~p"/api/v1/webhooks/vercel", %{type: "deployment.ready", id: "evt_bad"})
      |> json_response(401)

    assert %{"error" => %{"code" => "webhook_verification_failed"}} = response
  end

  test "provider webhook rejects actor context outside the supplied organization", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Webhook Org A", slug: "webhook-org-a"})

    {:ok, other_org} =
      Accounts.create_organization(%{name: "Webhook Org B", slug: "webhook-org-b"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: other_org.id,
        type: "integration",
        display_name: "Vercel",
        trust_level: "trusted"
      })

    response =
      conn
      |> post(~p"/api/v1/webhooks/vercel", %{
        organization_id: org.id,
        actor_id: actor.id,
        type: "deployment.ready",
        id: "evt_wrong_actor"
      })
      |> json_response(403)

    assert %{"error" => %{"code" => "webhook_context_invalid"}} = response
    assert Evidence.list_recent_events(1) == []
  end

  test "provider webhook rejects repository context outside the supplied organization", %{
    conn: conn
  } do
    {:ok, org} =
      Accounts.create_organization(%{name: "Webhook Repo Org A", slug: "webhook-repo-org-a"})

    {:ok, other_org} =
      Accounts.create_organization(%{name: "Webhook Repo Org B", slug: "webhook-repo-org-b"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "integration",
        display_name: "Vercel",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: other_org.id,
        name: "other-core",
        slug: "other-core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    response =
      conn
      |> post(~p"/api/v1/webhooks/vercel", %{
        organization_id: org.id,
        actor_id: actor.id,
        repository_id: repo.id,
        type: "deployment.ready",
        id: "evt_wrong_repo"
      })
      |> json_response(403)

    assert %{"error" => %{"code" => "webhook_context_invalid"}} = response
    assert Evidence.list_recent_events(1) == []
  end
end
