defmodule VelaWeb.Api.V1.MergeActions do
  @moduledoc """
  Merge candidate mutation actions for the v1 JSON API.
  """

  alias Vela.{Jobs, Repo}
  alias VelaWeb.Api.V1.IdempotentMutation
  alias VelaWeb.Api.V1.MutationAudit

  def simulate(conn, %{"id" => id}) do
    candidate =
      Vela.Merge.MergeCandidate
      |> Repo.get!(id)
      |> Repo.preload(:repository)

    IdempotentMutation.respond(conn, candidate.repository.organization_id, fn ->
      {:ok, job} =
        Repo.transaction(fn ->
          {:ok, job} =
            Jobs.enqueue(:merge_simulation, %{
              organization_id: candidate.repository.organization_id,
              repository_id: candidate.repository_id,
              merge_candidate_id: candidate.id,
              pull_request_id: candidate.pull_request_id
            })

          MutationAudit.record_job_accepted!(conn, %{
            organization_id: candidate.repository.organization_id,
            repository_id: candidate.repository_id,
            event_type: "merge.queued",
            resource_type: "merge_candidate",
            resource_id: candidate.id,
            job: job
          })

          job
        end)

      {202, %{data: %{merge_candidate_id: id, job: job_payload(job)}}}
    end)
  end

  defp job_payload(%Oban.Job{} = job) do
    %{id: job.id, status: "queued", kind: job.args["kind"], queue: job.queue}
  end
end
