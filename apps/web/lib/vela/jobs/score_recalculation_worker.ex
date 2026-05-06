defmodule Vela.Jobs.ScoreRecalculationWorker do
  use Oban.Worker, queue: :scoring, max_attempts: 5

  import Ecto.Query

  alias Vela.Evidence
  alias Vela.Forge.PullRequestFile
  alias Vela.Maestro
  alias Vela.Maestro.{LocalAnalyzers, ReadinessInputs}
  alias Vela.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with :ok <-
           Vela.Jobs.WorkerGuards.require_keys(
             args,
             ~w(kind organization_id repository_id pull_request_id actor_id)
           ),
         files <- pull_request_files(args["pull_request_id"]),
         analysis <- LocalAnalyzers.analyze_pull_request(%{files: files}),
         dimensions <- readiness_dimensions(analysis.dimensions),
         readiness <- Maestro.compute_readiness(%{dimensions: dimensions, confidence: "medium"}),
         input_refs <- ReadinessInputs.collect_for_pull_request(args["pull_request_id"]),
         {:ok, score} <-
           Maestro.create_readiness_score(%{
             organization_id: args["organization_id"],
             repository_id: args["repository_id"],
             score: readiness.score,
             verdict: readiness.verdict,
             confidence: readiness.confidence,
             dimensions: readiness.dimensions,
             explanation: explanation(analysis),
             input_refs: input_refs,
             dimension_explanations: dimension_explanations(analysis)
           }),
         {:ok, _event} <-
           Evidence.append_event(%{
             organization_id: args["organization_id"],
             repository_id: args["repository_id"],
             actor_id: args["actor_id"],
             event_type: "score.computed",
             resource_type: "readiness_score",
             resource_id: score.id,
             payload: %{
               score: score.score,
               verdict: score.verdict,
               confidence: score.confidence,
               input_refs: input_refs,
               findings: analysis.findings
             }
           }) do
      :ok
    end
  end

  defp pull_request_files(pull_request_id) do
    PullRequestFile
    |> where([file], file.pull_request_id == ^pull_request_id)
    |> Repo.all()
  end

  defp readiness_dimensions(local_dimensions) do
    %{
      "repository_trust" => 70,
      "change_risk" => local_dimensions["change_risk"],
      "test_evidence" => local_dimensions["test_evidence"],
      "security" => local_dimensions["security"],
      "performance" => 70,
      "agent_provenance" => 65,
      "launch_readiness" => 65
    }
  end

  defp explanation(%{input_summary: summary}) do
    "Recalculated from #{summary.changed_files} changed files, #{length(summary.sensitive_paths)} sensitive paths, and #{length(summary.test_paths)} test paths."
  end

  defp dimension_explanations(%{input_summary: summary}) do
    %{
      "repository_trust" =>
        "Repository trust uses the conservative local baseline until provider trust signals are linked.",
      "change_risk" =>
        "Change risk is derived from changed file count, sensitive paths, and config paths.",
      "test_evidence" =>
        "Test evidence is derived from changed test/spec paths compared with sensitive paths.",
      "security" =>
        "Security is derived from sensitive path and production configuration changes.",
      "performance" =>
        "Performance uses the conservative local baseline until runtime evidence is linked.",
      "agent_provenance" =>
        "Agent provenance uses the conservative local baseline until signed session evidence is linked.",
      "launch_readiness" =>
        "Launch readiness uses the conservative local baseline for #{summary.changed_files} changed files."
    }
  end
end
