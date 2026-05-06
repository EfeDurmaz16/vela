defmodule Vela.EvidenceTest do
  use Vela.DataCase

  alias Vela.{Accounts, Actors, Evidence, Repo}
  alias Vela.Evidence.TamperAlarm

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

  test "verifier detects tampered payloads" do
    %{actor: actor, org: org} = evidence_fixture!("tamper")

    {:ok, event} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "policy.evaluated",
        resource_type: "policy",
        payload: %{verdict: "allow"}
      })

    event
    |> Ecto.Changeset.change(payload: %{"verdict" => "block"})
    |> Repo.update!()

    assert {:error, %{event_id: event_id, event_hash: event_hash, reason: :payload_hash_mismatch}} =
             Evidence.verify_chain(org.id)

    assert event_id == event.id
    assert event_hash == event.event_hash
  end

  test "verifier accepts empty and single-event chains" do
    {:ok, empty_org} =
      Accounts.create_organization(%{name: "Empty Evidence Org", slug: "empty-evidence-org"})

    assert {:ok, %{count: 0, last_hash: nil}} = Evidence.verify_chain(empty_org.id)

    %{actor: actor, org: org} = evidence_fixture!("single")

    {:ok, event} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        payload: %{repo: "single"}
      })

    assert {:ok, %{count: 1, last_hash: last_hash}} = Evidence.verify_chain(org.id)
    assert last_hash == event.event_hash
  end

  test "export cursor is stable for events with the same timestamp" do
    %{actor: actor, org: org} = evidence_fixture!("export")
    inserted_at = %{DateTime.utc_now(:microsecond) | microsecond: {0, 6}}

    events =
      for index <- 1..3 do
        {:ok, event} =
          Evidence.append_event(%{
            organization_id: org.id,
            actor_id: actor.id,
            event_type: "policy.evaluated",
            resource_type: "policy",
            payload: %{index: index}
          })

        event
        |> Ecto.Changeset.change(inserted_at: inserted_at)
        |> Repo.update!()
      end

    expected_ids = events |> Enum.map(& &1.id) |> Enum.sort()

    first_page = Evidence.export_events(org.id, limit: 2)
    second_page = Evidence.export_events(org.id, limit: 2, after: first_page.next_cursor)

    returned_ids = Enum.map(first_page.data ++ second_page.data, & &1.id)

    assert Enum.sort(returned_ids) == expected_ids
    assert Enum.uniq(returned_ids) == returned_ids
    assert first_page.next_cursor != nil
    assert second_page.next_cursor == nil
  end

  test "rejects unknown critical event types" do
    %{actor: actor, org: org} = evidence_fixture!("unknown-event")

    assert {:error, changeset} =
             Evidence.append_event(%{
               organization_id: org.id,
               actor_id: actor.id,
               event_type: "merge.secret_backdoor",
               resource_type: "merge_candidate",
               payload: %{verdict: "allow"}
             })

    assert {"is invalid", _} = changeset.errors[:event_type]
  end

  test "requires an explicit actor for critical events and accepts system actors" do
    %{actor: actor, org: org} = evidence_fixture!("critical-actor")

    assert {:error, :critical_actor_required} =
             Evidence.append_event(%{
               organization_id: org.id,
               event_type: "merge.queued",
               resource_type: "merge_candidate",
               payload: %{candidate: "mc_1"}
             })

    assert {:ok, event} =
             Evidence.append_event(%{
               organization_id: org.id,
               actor_id: actor.id,
               event_type: "merge.queued",
               resource_type: "merge_candidate",
               payload: %{candidate: "mc_1"}
             })

    assert event.actor_id == actor.id
  end

  test "failed verification records one tamper alarm without duplicate alarm spam" do
    %{actor: actor, org: org} = evidence_fixture!("tamper-alarm")

    {:ok, event} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "policy.evaluated",
        resource_type: "policy",
        payload: %{verdict: "allow"}
      })

    event
    |> Ecto.Changeset.change(payload: %{"verdict" => "block"})
    |> Repo.update!()

    assert {:error, %{reason: :payload_hash_mismatch}} = Evidence.verify_chain(org.id)
    assert {:error, %{reason: :payload_hash_mismatch}} = Evidence.verify_chain(org.id)

    assert [
             %TamperAlarm{
               organization_id: organization_id,
               evidence_event_id: evidence_event_id,
               event_hash: event_hash,
               reason: "payload_hash_mismatch",
               status: "open"
             }
           ] = Repo.all(TamperAlarm)

    assert organization_id == org.id
    assert evidence_event_id == event.id
    assert event_hash == event.event_hash
  end

  defp evidence_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Evidence #{suffix}",
        slug: "evidence-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Evidence Actor #{suffix}",
        trust_level: "trusted"
      })

    %{actor: actor, org: org}
  end
end
