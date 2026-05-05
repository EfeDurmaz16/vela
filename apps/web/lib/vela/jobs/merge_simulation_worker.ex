defmodule Vela.Jobs.MergeSimulationWorker do
  use Oban.Worker, queue: :merge, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    :ok = Vela.Jobs.WorkerGuards.require_keys(args, ~w(kind organization_id))
  end
end
