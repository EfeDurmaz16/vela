defmodule Vela.IntegrationEventTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Evidence, Integrations}

  test "all declared integration providers have concrete event normalizers" do
    for provider <- Vela.Integrations.Integration.providers() do
      assert {:ok, adapter} = Integrations.adapter(provider)

      assert {:ok, %{event_type: "integration.event_received", payload: payload}} =
               adapter.normalize_event(%{"type" => "deployment.ready", "id" => "evt_1"})

      assert payload["provider"] == provider
    end
  end

  test "integration events are persisted as evidence events" do
    {:ok, org} = Accounts.create_organization(%{name: "Events Org", slug: "events-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "integration",
        display_name: "Vercel",
        trust_level: "trusted",
        external_ref: "integration:vercel"
      })

    {:ok, event} =
      Integrations.record_event(%{
        provider: "vercel",
        organization_id: org.id,
        actor_id: actor.id,
        resource_type: "integration",
        payload: %{"type" => "deployment.ready", "id" => "evt_1"}
      })

    assert event.event_type == "integration.event_received"
    assert event.payload["provider"] == "vercel"
    assert [%Vela.Evidence.EvidenceEvent{}] = Evidence.list_recent_events(1)
  end
end
