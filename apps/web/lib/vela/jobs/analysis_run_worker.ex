defmodule Vela.Jobs.AnalysisRunWorker do
  use Oban.Worker, queue: :analysis, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    :ok = Vela.Jobs.WorkerGuards.require_keys(args, ~w(kind organization_id))
  end
end
