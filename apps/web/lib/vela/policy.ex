defmodule Vela.Policy do
  @moduledoc """
  Fail-closed Phase 0 policy decisions for merges and agent scopes.
  """

  def evaluate_merge(input) do
    reasons =
      []
      |> check_actor(input[:actor])
      |> check_pr(input[:pull_request])
      |> check_readiness(input[:readiness_score])
      |> check_merge_candidate(input[:merge_candidate])
      |> check_agent_scope(input)

    verdict =
      cond do
        Enum.any?(reasons, &String.starts_with?(&1, "block:")) -> :block
        Enum.any?(reasons, &String.starts_with?(&1, "override:")) -> :requires_human_override
        Enum.any?(reasons, &String.starts_with?(&1, "review:")) -> :requires_human_override
        true -> :allow
      end

    %{
      verdict: verdict,
      reasons: reasons,
      evidence_payload: %{decision: verdict, reasons: reasons}
    }
  end

  defp check_actor(reasons, nil), do: ["block: missing actor" | reasons]
  defp check_actor(reasons, %{trust_level: "blocked"}), do: ["block: actor is blocked" | reasons]
  defp check_actor(reasons, _actor), do: reasons

  defp check_pr(reasons, nil), do: ["block: missing pull request" | reasons]

  defp check_pr(reasons, %{status: status}) when status in ["closed", "merged"],
    do: ["block: pull request is #{status}" | reasons]

  defp check_pr(reasons, _pr), do: reasons

  defp check_readiness(reasons, nil), do: ["override: missing readiness score" | reasons]

  defp check_readiness(reasons, %{verdict: "block"}),
    do: ["block: readiness verdict is block" | reasons]

  defp check_readiness(reasons, %{verdict: "wait"}),
    do: ["override: readiness verdict is wait" | reasons]

  defp check_readiness(reasons, _score), do: reasons

  defp check_merge_candidate(reasons, nil), do: ["override: missing merge candidate" | reasons]

  defp check_merge_candidate(reasons, %{status: "failed"}),
    do: ["block: merge candidate failed" | reasons]

  defp check_merge_candidate(reasons, _candidate), do: reasons

  defp check_agent_scope(reasons, %{actor: %{type: "agent"}, agent_policy: nil}),
    do: ["block: missing agent policy" | reasons]

  defp check_agent_scope(reasons, %{actor: %{type: "agent"}, agent_policy: policy} = input) do
    changed_paths = input[:changed_paths] || []

    reasons
    |> maybe_block_merge(policy, input[:merge_intent])
    |> maybe_require_human_review(policy, input[:human_review_status])
    |> check_forbidden_paths(policy, changed_paths)
    |> check_allowed_paths(policy, changed_paths)
  end

  defp check_agent_scope(reasons, _input), do: reasons

  defp maybe_block_merge(reasons, %{can_merge: false}, true),
    do: ["block: agent cannot merge" | reasons]

  defp maybe_block_merge(reasons, _policy, _merge_intent), do: reasons

  defp maybe_require_human_review(reasons, %{requires_human_approval: true}, status)
       when status != "approve" do
    ["review: human approval required" | reasons]
  end

  defp maybe_require_human_review(reasons, _policy, _status), do: reasons

  defp check_forbidden_paths(reasons, policy, changed_paths) do
    forbidden = policy.forbidden_paths || []

    if Enum.any?(changed_paths, &matches_any?(&1, forbidden)) do
      ["block: changed path matches forbidden_paths" | reasons]
    else
      reasons
    end
  end

  defp check_allowed_paths(reasons, policy, changed_paths) do
    allowed = policy.allowed_paths || []

    if allowed != [] and Enum.any?(changed_paths, &(not matches_any?(&1, allowed))) do
      ["block: changed path is outside allowed_paths" | reasons]
    else
      reasons
    end
  end

  defp matches_any?(path, prefixes), do: Enum.any?(prefixes, &String.starts_with?(path, &1))
end
