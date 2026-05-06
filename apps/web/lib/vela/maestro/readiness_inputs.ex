defmodule Vela.Maestro.ReadinessInputs do
  @moduledoc """
  Structured lineage for repository readiness scores.

  Readiness scores should be reconstructable from the PR metadata that fed the
  decision. This helper records the concrete local rows used as inputs without
  forcing the score itself to understand provider-specific details.
  """

  import Ecto.Query

  alias Vela.Forge.{CheckRun, PullRequestFile, Review}
  alias Vela.Repo

  def collect_for_pull_request(pull_request_id) do
    %{
      "pull_request_id" => pull_request_id,
      "pull_request_file_ids" => ids(PullRequestFile, pull_request_id),
      "review_ids" => ids(Review, pull_request_id),
      "check_run_ids" => ids(CheckRun, pull_request_id)
    }
  end

  defp ids(schema, pull_request_id) do
    schema
    |> where([row], row.pull_request_id == ^pull_request_id)
    |> order_by([row], asc: row.inserted_at, asc: row.id)
    |> select([row], row.id)
    |> Repo.all()
  end
end
