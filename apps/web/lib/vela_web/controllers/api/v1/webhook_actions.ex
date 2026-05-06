defmodule VelaWeb.Api.V1.WebhookActions do
  @moduledoc """
  Provider webhook ingestion actions for the v1 JSON API.
  """

  import Ecto.Query
  import Phoenix.Controller
  import Plug.Conn

  alias Vela.{Integrations, Repo, Webhooks}

  def ingest(
        conn,
        %{"provider" => provider, "organization_id" => organization_id, "actor_id" => actor_id} =
          params
      ) do
    with :ok <- Webhooks.verify_provider_request(provider, conn),
         :ok <-
           validate_context(organization_id, actor_id, Map.get(params, "repository_id")),
         {:ok, event} <-
           Integrations.record_event(%{
             provider: provider,
             organization_id: organization_id,
             actor_id: actor_id,
             repository_id: Map.get(params, "repository_id"),
             resource_type: "integration",
             payload:
               Map.drop(params, ["provider", "organization_id", "actor_id", "repository_id"])
           }) do
      accepted(conn, provider, event.id)
    else
      {:error, reason} -> verification_error(conn, reason)
      {:invalid_context, reason} -> context_error(conn, reason)
    end
  end

  def ingest(conn, %{"provider" => provider}) do
    with :ok <- Webhooks.verify_provider_request(provider, conn) do
      accepted(conn, provider, nil)
    else
      {:error, reason} -> verification_error(conn, reason)
    end
  end

  def validate_context(organization_id, actor_id, repository_id) do
    with true <- resource_belongs_to?(Vela.Actors.Actor, actor_id, organization_id),
         true <-
           is_nil(repository_id) or
             resource_belongs_to?(Vela.Forge.Repository, repository_id, organization_id) do
      :ok
    else
      _ -> {:invalid_context, :tenant_mismatch}
    end
  end

  defp accepted(conn, provider, evidence_event_id) do
    conn
    |> put_status(:accepted)
    |> json(%{data: %{provider: provider, accepted: true, evidence_event_id: evidence_event_id}})
  end

  defp verification_error(conn, reason) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: %{code: "webhook_verification_failed", reason: to_string(reason)}})
  end

  defp context_error(conn, reason) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "webhook_context_invalid", reason: to_string(reason)}})
  end

  defp resource_belongs_to?(schema, id, organization_id) do
    query = from resource in schema, where: resource.id == ^id

    case Repo.one(query) do
      %{organization_id: ^organization_id} -> true
      _ -> false
    end
  end
end
