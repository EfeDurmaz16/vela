defmodule Vela.JobsTest do
  use ExUnit.Case, async: true

  alias Vela.Jobs

  test "expensive backend work has explicit Oban worker contracts" do
    for {kind, worker, queue} <- job_contracts() do
      worker_name = worker |> Module.split() |> Enum.join(".")
      kind_name = to_string(kind)

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{worker: ^worker_name, queue: ^queue, args: %{"kind" => ^kind_name}}
             } = Jobs.new(kind, %{organization_id: Ecto.UUID.generate()})
    end
  end

  test "job domain registries cover the public worker map exactly" do
    domain_workers =
      [
        Vela.Jobs.RepositoryJobs,
        Vela.Jobs.AnalysisJobs,
        Vela.Jobs.ScoringJobs,
        Vela.Jobs.MergeJobs
      ]
      |> Enum.map(& &1.workers())
      |> Enum.reduce(%{}, &Map.merge/2)

    assert Jobs.workers() == domain_workers

    assert Map.keys(Jobs.workers()) |> Enum.sort() ==
             job_contracts() |> Keyword.keys() |> Enum.sort()
  end

  test "job constructors stringify atom keys while preserving explicit values" do
    assert %Ecto.Changeset{
             valid?: true,
             changes: %{
               args: %{
                 "kind" => "repo_sync",
                 "organization_id" => "org_1",
                 "repository_id" => "repo_1",
                 "pull_request_number" => 17
               }
             }
           } =
             Jobs.new(:repo_sync, %{
               organization_id: "org_1",
               repository_id: "repo_1",
               pull_request_number: 17
             })
  end

  defp job_contracts do
    [
      repo_import: {Vela.Jobs.RepoImportWorker, "imports"},
      analysis_run: {Vela.Jobs.AnalysisRunWorker, "analysis"},
      readiness_score: {Vela.Jobs.ReadinessScoreWorker, "scoring"},
      score_recalculation: {Vela.Jobs.ScoreRecalculationWorker, "scoring"},
      trust_score: {Vela.Jobs.TrustScoreWorker, "scoring"},
      repo_sync: {Vela.Jobs.RepoSyncWorker, "sync"},
      merge_simulation: {Vela.Jobs.MergeSimulationWorker, "merge"}
    ]
  end
end
