defmodule Vela.Repo.Migrations.AddReviewProviderMetadata do
  use Ecto.Migration

  def change do
    alter table(:reviews) do
      add :provider, :string
      add :external_id, :string
      add :external_author_login, :string
      add :submitted_at, :utc_datetime
    end

    create unique_index(:reviews, [:pull_request_id, :provider, :external_id],
             where: "provider IS NOT NULL AND external_id IS NOT NULL"
           )
  end
end
