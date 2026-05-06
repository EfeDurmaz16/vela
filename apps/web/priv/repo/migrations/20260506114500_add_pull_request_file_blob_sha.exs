defmodule Vela.Repo.Migrations.AddPullRequestFileBlobSha do
  use Ecto.Migration

  def change do
    alter table(:pull_request_files) do
      add :blob_sha, :string
    end

    create index(:pull_request_files, [:blob_sha])
  end
end
