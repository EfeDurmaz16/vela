defmodule VelaWeb.Api.V1.WebhookActionsTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Forge}
  alias VelaWeb.Api.V1.WebhookActions

  setup do
    previous = Application.get_env(:vela, :webhooks)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :webhooks, previous),
        else: Application.delete_env(:vela, :webhooks)
    end)
  end

  test "validate_context accepts actor and repository in the supplied organization" do
    %{actor: actor, organization: organization, repo: repo} = fixture!("valid")

    assert :ok == WebhookActions.validate_context(organization.id, actor.id, repo.id)
  end

  test "validate_context rejects actor tenant mismatch" do
    %{organization: organization} = fixture!("actor-org")
    %{actor: actor} = fixture!("actor-other")

    assert {:invalid_context, :tenant_mismatch} ==
             WebhookActions.validate_context(organization.id, actor.id, nil)
  end

  test "validate_context rejects repository tenant mismatch" do
    %{actor: actor, organization: organization} = fixture!("repo-org")
    %{repo: repo} = fixture!("repo-other")

    assert {:invalid_context, :tenant_mismatch} ==
             WebhookActions.validate_context(organization.id, actor.id, repo.id)
  end

  test "ingest records evidence only after valid context" do
    %{actor: actor, organization: organization, repo: repo} = fixture!("ingest-valid")

    response =
      Plug.Test.conn(:post, "/api/v1/webhooks/vercel")
      |> WebhookActions.ingest(%{
        "provider" => "vercel",
        "organization_id" => organization.id,
        "actor_id" => actor.id,
        "repository_id" => repo.id,
        "type" => "deployment.ready",
        "id" => "evt_valid"
      })
      |> json_response(202)

    assert %{"data" => %{"accepted" => true, "evidence_event_id" => event_id}} = response
    assert Evidence.list_recent_events(1) |> hd() |> Map.fetch!(:id) == event_id
  end

  test "ingest rejects invalid context before evidence is recorded" do
    %{organization: organization} = fixture!("ingest-org")
    %{actor: actor} = fixture!("ingest-other")

    response =
      Plug.Test.conn(:post, "/api/v1/webhooks/vercel")
      |> WebhookActions.ingest(%{
        "provider" => "vercel",
        "organization_id" => organization.id,
        "actor_id" => actor.id,
        "type" => "deployment.ready",
        "id" => "evt_invalid"
      })
      |> json_response(403)

    assert response == %{
             "error" => %{"code" => "webhook_context_invalid", "reason" => "tenant_mismatch"}
           }

    assert Evidence.list_recent_events(1) == []
  end

  defp fixture!(suffix) do
    {:ok, organization} =
      Accounts.create_organization(%{
        name: "Webhook Action #{suffix}",
        slug: "webhook-action-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: organization.id,
        type: "integration",
        display_name: "Webhook Actor #{suffix}",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: organization.id,
        name: "Webhook Repo #{suffix}",
        slug: "webhook-repo-#{suffix}",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    %{actor: actor, organization: organization, repo: repo}
  end
end
