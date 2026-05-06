defmodule Vela.Repo.Migrations.NormalizeReviewProviderUniqueIndex do
  use Ecto.Migration

  def change do
    drop_if_exists index(:reviews, [:pull_request_id, :provider, :external_id],
                     name: :reviews_pull_request_id_provider_external_id_index
                   )

    create unique_index(:reviews, [:pull_request_id, :provider, :external_id])
  end
end
