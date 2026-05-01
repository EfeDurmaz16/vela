defmodule Vela.Pipelines.Runner do
  use Vela.Schema

  schema "runners" do
    field :name, :string
    field :type, :string
    field :labels, {:array, :string}, default: []
    field :status, :string
    field :last_seen_at, :utc_datetime

    belongs_to :organization, Vela.Accounts.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(runner, attrs) do
    runner
    |> cast(attrs, [:organization_id, :name, :type, :labels, :status, :last_seen_at])
    |> validate_required([:organization_id, :name, :type, :status])
  end
end
