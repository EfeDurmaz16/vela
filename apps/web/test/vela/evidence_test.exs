defmodule Vela.EvidenceTest do
  use Vela.DataCase

  alias Vela.{Accounts, Actors, Evidence}

  test "appends a hash-chained evidence stream" do
    {:ok, org} = Accounts.create_organization(%{name: "Test Org", slug: "test-org", plan: "free"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Vela Test",
        trust_level: "trusted"
      })

    {:ok, first} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        payload: %{repo: "demo"}
      })

    Process.sleep(5)

    {:ok, second} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "policy.evaluated",
        resource_type: "policy",
        payload: %{verdict: "allow"}
      })

    assert first.prev_event_hash == nil
    assert second.prev_event_hash == first.event_hash
    assert first.payload_hash != second.payload_hash
    assert String.starts_with?(first.event_hash, "sha256:")
  end
end
