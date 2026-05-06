defmodule VelaWeb.EvidenceVerificationApiTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Repo}

  test "verifies a healthy organization evidence chain", %{conn: conn} do
    %{actor: actor, org: org} = evidence_fixture!("healthy")

    {:ok, event} =
      Evidence.append_event(%{
        organization_id: org.id,
        actor_id: actor.id,
        event_type: "repo.created",
        resource_type: "repository",
        payload: %{repo: "healthy"}
      })

    response =
      conn
      |> get(~p"/api/v1/evidence-events/verify", %{organization_id: org.id})
      |> json_response(200)

    assert response == %{
             "data" => %{
               "valid" => true,
               "organization_id" => org.id,
               "repository_id" => nil,
               "count" => 1,
               "last_hash" => event.event_hash
             }
           }
  end

  test "reports a broken organization evidence chain", %{conn: conn} do
    %{actor: actor, org: org} = evidence_fixture!("broken")

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

    response =
      conn
      |> get(~p"/api/v1/evidence-events/verify", %{organization_id: org.id})
      |> json_response(200)

    assert response == %{
             "data" => %{
               "valid" => false,
               "organization_id" => org.id,
               "repository_id" => nil,
               "reason" => "payload_hash_mismatch",
               "event_id" => event.id,
               "event_hash" => event.event_hash
             }
           }
  end

  test "requires organization_id", %{conn: conn} do
    response =
      conn
      |> get(~p"/api/v1/evidence-events/verify")
      |> json_response(422)

    assert response == %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"organization_id" => ["is required"]}
             }
           }
  end

  defp evidence_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Evidence Verify #{suffix}",
        slug: "evidence-verify-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Evidence Verifier #{suffix}",
        trust_level: "trusted"
      })

    %{actor: actor, org: org}
  end
end
