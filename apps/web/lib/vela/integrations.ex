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
