defmodule Vela.Integrations do
  @moduledoc """
  Adapter boundaries for WorkOS, GitHub import/mirror, webhooks, and external services.
  """

  alias Vela.Integrations.{Environment, Integration, ServiceConnection}
  alias Vela.Repo

  @callback import_repository(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_webhook(map(), binary(), binary()) :: :ok | {:error, term()}
  @callback normalize_event(map()) :: {:ok, map()} | {:error, term()}

  def create_integration(attrs),
    do: %Integration{} |> Integration.changeset(attrs) |> Repo.insert()

  def create_environment(attrs),
    do: %Environment{} |> Environment.changeset(attrs) |> Repo.insert()

  def create_service_connection(attrs),
    do: %ServiceConnection{} |> ServiceConnection.changeset(attrs) |> Repo.insert()

  def list_integrations, do: Repo.all(Integration)
  def list_environments, do: Repo.all(Environment)
  def list_service_connections, do: Repo.all(ServiceConnection)

  def adapter(provider), do: Map.fetch(adapter_registry(), provider)

  def record_event(attrs) do
    with {:ok, adapter} <- adapter(attrs.provider),
         {:ok, normalized} <- adapter.normalize_event(attrs.payload) do
      Vela.Evidence.append_event(%{
        organization_id: attrs.organization_id,
        repository_id: Map.get(attrs, :repository_id),
        actor_id: attrs.actor_id,
        event_type: normalized.event_type,
        resource_type: Map.get(attrs, :resource_type, normalized.resource_type),
        resource_id: Map.get(attrs, :resource_id),
        payload: normalized.payload
      })
    end
  end

  defp adapter_registry do
    %{
      "vercel" => Vela.Integrations.Adapters.Vercel,
      "supabase" => Vela.Integrations.Adapters.Supabase,
      "neon" => Vela.Integrations.Adapters.Neon,
      "workos" => Vela.Integrations.Adapters.WorkOS,
      "sentry" => Vela.Integrations.Adapters.Sentry,
      "axiom" => Vela.Integrations.Adapters.Axiom,
      "trigger_dev" => Vela.Integrations.Adapters.TriggerDev,
      "inngest" => Vela.Integrations.Adapters.Inngest,
      "upstash" => Vela.Integrations.Adapters.Upstash,
      "modal" => Vela.Integrations.Adapters.Modal,
      "stripe" => Vela.Integrations.Adapters.Stripe,
      "cloudflare" => Vela.Integrations.Adapters.Cloudflare,
      "github" => Vela.Integrations.Adapters.GitHub
    }
  end

  def phase_zero_status do
    %{
      workos: "interface-defined",
      github_import: "interface-defined",
      webhooks: "signature-verification-boundary-defined",
      adapters: Integration.providers(),
      production_auth: "planned-phase-1"
    }
  end
end
