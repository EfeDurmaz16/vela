defmodule VelaWeb.IntegrationWebhookTest do
  use VelaWeb.ConnCase, async: true

  alias Vela.{Accounts, Actors, Evidence}

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
end
