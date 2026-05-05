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

  test "chains evidence per repository when repository context exists" do
    {:ok, org} = Accounts.create_organization(%{name: "Repo Chain Org", slug: "repo-chain-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Vela Test",
        trust_level: "trusted"
      })

    {:ok, repo_a} =
      Vela.Forge.create_repository(%{
        organization_id: org.id,
        name: "repo-a",
        slug: "repo-a",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, repo_b} =
      Vela.Forge.create_repository(%{
        organization_id: org.id,
        name: "repo-b",
        slug: "repo-b",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, first_a} =
      Evidence.append_event(%{
        organization_id: org.id,
        repository_id: repo_a.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        resource_id: repo_a.id,
        payload: %{repo: "a"}
      })

    {:ok, first_b} =
      Evidence.append_event(%{
        organization_id: org.id,
        repository_id: repo_b.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        resource_id: repo_b.id,
        payload: %{repo: "b"}
      })

    {:ok, second_a} =
      Evidence.append_event(%{
        organization_id: org.id,
        repository_id: repo_a.id,
        actor_id: actor.id,
        event_type: "policy.evaluated",
        resource_type: "repository",
        resource_id: repo_a.id,
        payload: %{verdict: "allow"}
      })

    assert first_a.prev_event_hash == nil
    assert first_b.prev_event_hash == nil
    assert second_a.prev_event_hash == first_a.event_hash
  end
end
