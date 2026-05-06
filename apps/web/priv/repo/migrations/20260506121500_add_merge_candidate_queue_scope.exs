defmodule Vela.Repo.Migrations.AddMergeCandidateQueueScope do
  use Ecto.Migration

  def change do
    alter table(:merge_candidates) do
      add :target_branch, :string
    end

    create index(:merge_candidates, [:repository_id, :target_branch, :status])

    create unique_index(:merge_candidates, [:repository_id, :target_branch, :queue_position],
             where: "queue_position IS NOT NULL"
           )
  end
end
