defmodule Vela.Jobs.ScoreRecalculationWorker do
  use Oban.Worker, queue: :scoring, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    :ok =
      Vela.Jobs.WorkerGuards.require_keys(
        args,
        ~w(kind organization_id repository_id pull_request_id)
      )
  end
end
