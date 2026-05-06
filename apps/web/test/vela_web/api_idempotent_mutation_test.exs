defmodule VelaWeb.Api.V1.IdempotentMutationTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Repo}
  alias Vela.Idempotency.IdempotencyKey
  alias VelaWeb.Api.V1.IdempotentMutation

  test "respond returns the mutation response and stores an idempotency record" do
    %{actor: actor, organization: organization} = actor_fixture!("success")

    conn =
      mutation_conn(%{repo: "vela"})
      |> put_req_header("idempotency-key", "idem-success-1")
      |> assign(:current_actor, actor)
      |> IdempotentMutation.respond(organization.id, fn ->
        {202, %{data: %{accepted: true}}}
      end)

    assert json_response(conn, 202) == %{"data" => %{"accepted" => true}}
    assert Repo.get_by!(IdempotencyKey, organization_id: organization.id, key: "idem-success-1")
  end

  test "respond replays the stored response for the same request hash" do
    %{actor: actor, organization: organization} = actor_fixture!("replay")

    first =
      mutation_conn(%{repo: "vela"})
      |> put_req_header("idempotency-key", "idem-replay-1")
      |> assign(:current_actor, actor)
      |> IdempotentMutation.respond(organization.id, fn ->
        {202, %{data: %{job_id: 123}}}
      end)

    second =
      mutation_conn(%{repo: "vela"})
      |> put_req_header("idempotency-key", "idem-replay-1")
      |> assign(:current_actor, actor)
      |> IdempotentMutation.respond(organization.id, fn ->
        flunk("replayed idempotent mutations must not execute the mutation function")
      end)

    assert json_response(first, 202) == %{"data" => %{"job_id" => 123}}
    assert json_response(second, 202) == json_response(first, 202)
  end

  test "respond returns conflict when an idempotency key is reused for another request" do
    %{actor: actor, organization: organization} = actor_fixture!("conflict")

    mutation_conn(%{repo: "vela"})
    |> put_req_header("idempotency-key", "idem-conflict-1")
    |> assign(:current_actor, actor)
    |> IdempotentMutation.respond(organization.id, fn ->
      {202, %{data: %{accepted: true}}}
    end)

    conflict =
      mutation_conn(%{repo: "other"})
      |> put_req_header("idempotency-key", "idem-conflict-1")
      |> assign(:current_actor, actor)
      |> IdempotentMutation.respond(organization.id, fn ->
        flunk("conflicting idempotent mutations must not execute the mutation function")
      end)

    assert json_response(conflict, 409) == %{
             "error" => %{"code" => "idempotency_key_reused"}
           }
  end

  defp mutation_conn(params) do
    Plug.Test.conn(:post, "/api/v1/test-mutation")
    |> Map.put(:params, params)
  end

  defp actor_fixture!(suffix) do
    {:ok, organization} =
      Accounts.create_organization(%{
        name: "Idempotent Mutation #{suffix}",
        slug: "idempotent-mutation-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: organization.id,
        type: "human",
        display_name: "API Actor #{suffix}",
        trust_level: "trusted"
      })

    %{organization: organization, actor: actor}
  end
end
