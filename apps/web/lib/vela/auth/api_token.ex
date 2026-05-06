defmodule Vela.Auth.ApiToken do
  use Vela.Schema

  @statuses ~w(active revoked expired)
  @scopes ~w(
    repositories:read
    repositories:write
    pull_requests:read
    pull_requests:write
    evidence:read
    merge:write
    admin
  )

  schema "api_tokens" do
    field :name, :string
    field :description, :string
    field :token_hash, :string
    field :scopes, {:array, :string}, default: []
    field :status, :string, default: "active"
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def scopes, do: @scopes

  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [
      :organization_id,
      :actor_id,
      :name,
      :description,
      :token_hash,
      :scopes,
      :status,
      :expires_at,
      :last_used_at,
      :revoked_at
    ])
    |> validate_required([:organization_id, :actor_id, :name, :scopes, :status, :expires_at])
    |> validate_non_empty_scopes()
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_subset(:scopes, @scopes)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:actor_id)
  end

  defp validate_non_empty_scopes(changeset) do
    case get_field(changeset, :scopes) do
      [_ | _] -> changeset
      _ -> add_error(changeset, :scopes, "can't be blank")
    end
  end
end
