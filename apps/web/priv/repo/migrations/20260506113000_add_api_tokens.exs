defmodule Vela.Repo.Migrations.AddApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:actors, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :description, :text
      add :token_hash, :string
      add :scopes, {:array, :string}, null: false, default: []
      add :status, :string, null: false, default: "active"
      add :expires_at, :utc_datetime, null: false
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:api_tokens, [:organization_id, :status])
    create index(:api_tokens, [:actor_id])
    create unique_index(:api_tokens, [:token_hash], where: "token_hash IS NOT NULL")
  end
end
