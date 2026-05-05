defmodule Vela.Integrations.Environment do
  use Vela.Schema

  @types ~w(development preview staging production)
  @statuses ~w(active disabled archived)

  schema "environments" do
    field :name, :string
    field :type, :string, default: "preview"
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    has_many :service_connections, Vela.Integrations.ServiceConnection

    timestamps(type: :utc_datetime)
  end

  def changeset(environment, attrs) do
    environment
    |> cast(attrs, [:organization_id, :repository_id, :name, :type, :status, :metadata])
    |> validate_required([:organization_id, :repository_id, :name, :type, :status])
    |> Vela.Validation.validate_inclusion(:type, @types)
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint([:repository_id, :name])
  end
end
