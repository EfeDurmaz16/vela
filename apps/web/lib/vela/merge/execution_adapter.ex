defmodule Vela.Merge.ExecutionAdapter do
  @moduledoc """
  Adapter contract for the final merge execution boundary.

  Vela owns gate evaluation, queue state, evidence, and audit semantics. Provider
  adapters own the irreversible act of landing the merge in GitHub or another
  forge.
  """

  @type request :: %{
          required(:merge_candidate_id) => binary(),
          required(:repository_id) => binary(),
          required(:pull_request_id) => binary(),
          required(:base_sha) => String.t(),
          required(:head_sha) => String.t(),
          optional(:target_branch) => String.t() | nil,
          optional(:expected_tree_hash) => String.t() | nil,
          optional(:metadata) => map()
        }

  @type result :: %{
          required(:merge_sha) => String.t(),
          optional(:merge_tree_hash) => String.t() | nil,
          optional(:provider) => String.t() | nil,
          optional(:metadata) => map()
        }

  @callback execute(request()) :: {:ok, result()} | {:error, term()}
end
