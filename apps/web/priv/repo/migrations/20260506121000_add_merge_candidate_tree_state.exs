defmodule Vela.Repo.Migrations.AddMergeCandidateTreeState do
  use Ecto.Migration

  def change do
    alter table(:merge_candidates) do
      add :tree_state, :string, null: false, default: "unmerged"
    end

    create index(:merge_candidates, [:tree_state])
  end
end
