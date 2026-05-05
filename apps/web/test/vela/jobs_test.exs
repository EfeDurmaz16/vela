defmodule Vela.JobsTest do
  use ExUnit.Case, async: true

  alias Vela.Jobs

  test "expensive backend work has explicit Oban worker contracts" do
    for {kind, worker, queue} <- [
          {:repo_import, Vela.Jobs.RepoImportWorker, "imports"},
          {:analysis_run, Vela.Jobs.AnalysisRunWorker, "analysis"},
          {:readiness_score, Vela.Jobs.ReadinessScoreWorker, "scoring"},
          {:trust_score, Vela.Jobs.TrustScoreWorker, "scoring"},
          {:repo_sync, Vela.Jobs.RepoSyncWorker, "sync"},
          {:merge_simulation, Vela.Jobs.MergeSimulationWorker, "merge"}
        ] do
      worker_name = worker |> Module.split() |> Enum.join(".")
      kind_name = to_string(kind)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{worker: ^worker_name, queue: ^queue, args: %{"kind" => ^kind_name}}
             } = Jobs.new(kind, %{organization_id: Ecto.UUID.generate()})
    end
  end
end
