defmodule Vela.Integrations.ServiceConnection do
  use Vela.Schema

  @statuses ~w(active disabled error pending)

  schema "service_connections" do
    field :service_name, :string
    field :service_type, :string
    field :status, :string, default: "active"
    field :external_ref, :string
    field :metadata, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :integration, Vela.Integrations.Integration
    belongs_to :environment, Vela.Integrations.Environment

    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :integration_id,
      :environment_id,
      :service_name,
      :service_type,
      :status,
      :external_ref,
      :metadata
    ])
    |> validate_required([
      :organization_id,
      :repository_id,
      :integration_id,
      :service_name,
      :service_type,
      :status
    ])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
  end
end
