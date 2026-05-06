defmodule Vela.Repo.Migrations.AddReadinessScoreInputRefs do
  use Ecto.Migration

  def change do
    alter table(:readiness_scores) do
      add :input_refs, :map, default: %{}, null: false
    end
  end
end
