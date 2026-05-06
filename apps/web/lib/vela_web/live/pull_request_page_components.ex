defmodule VelaWeb.PullRequestPageComponents do
  @moduledoc """
  Pull request cockpit rendering for the app LiveView.
  """

  use VelaWeb, :html

  attr :pull_request, :map, required: true
  attr :score, :map, required: true
  attr :merge_candidate, :map, default: nil

  def pull_request_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <.status_banner verdict={@score.verdict} title={@pull_request.title} body={@score.explanation} />

      <section class="grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
        <div class="panel p-5">
          <.score_bar score={@score.overall_score} />
          <div class="mt-5 grid grid-cols-2 gap-3 text-sm">
            <.score_cell label="Behavioral" value={@score.behavioral_score} />
            <.score_cell label="Correctness" value={@score.correctness_score} />
            <.score_cell label="Security" value={@score.security_score} />
            <.score_cell label="Performance" value={@score.performance_score} />
            <.score_cell label="UX" value={@score.ux_score} />
            <.score_cell label="Agent provenance" value={@score.agent_provenance_score} />
          </div>
        </div>
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Behavioral Summary
          </h2>
          <p class="mt-4 text-sm leading-6 text-fg">{@pull_request.behavioral_summary}</p>
          <p class="mt-4 text-sm leading-6 text-muted-fg">{@pull_request.intent}</p>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <.simple_list title="Risk Map" items={risk_items(@score, @pull_request)} />
        <.simple_list title="Test Evidence" items={test_items(@score)} />
        <.simple_list title="Agent Provenance" items={agent_items(@pull_request.author_actor)} />
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <.simple_list title="Review Requirements" items={review_items(@pull_request)} />
        <.simple_list title="Merge Simulation" items={merge_items(@merge_candidate)} />
        <.simple_list title="Rollback Plan" items={rollback_items(@merge_candidate)} />
      </section>

      <div class="panel p-5">
        <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">Raw Code Diff</h2>
        <pre class="mt-4 overflow-auto rounded-lg border border-border bg-bg p-4 text-xs text-muted-fg"><code>Interface defined. Phase 0 uses mock-backed diff metadata.

      @@ policy/agent_spending_policy.ex
      + enforce fail-closed policy decision before delegated spending action
      + append policy.evaluated evidence event

      @@ test/policy/agent_spending_policy_test.exs
      + covers blocked path scope and missing approval cases</code></pre>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp score_cell(assigns) do
    ~H"""
    <div class="rounded-md border border-border p-3">
      <p class="text-xs uppercase tracking-[0.12em] text-muted-fg">{@label}</p>
      <p class="mt-2 text-xl font-semibold text-fg">{@value}</p>
    </div>
    """
  end

  defp risk_items(score, pr) do
    findings =
      Enum.map(score.blocking_findings, fn finding ->
        %{title: finding["severity"] || "risk", body: finding["message"] || inspect(finding)}
      end)

    if findings == [] do
      [
        %{
          title: "Bounded #{pr.risk_level} risk",
          body:
            "No blocking findings. Security #{score.security_score}, correctness #{score.correctness_score}."
        },
        %{
          title: "Policy-aware score",
          body: "The score is evaluated with repository profile weighting."
        }
      ]
    else
      findings
    end
  end

  defp test_items(score) do
    [
      %{
        title: "Test evidence #{score.test_evidence_score}",
        body: Enum.join(score.required_actions, " ")
      },
      %{
        title: "Runner model",
        body: "BYO runner metadata exists; hosted CI is intentionally deferred."
      }
    ]
  end

  defp agent_items(actor) do
    [
      %{
        title: actor.display_name,
        body: "Actor type #{actor.type}, trust level #{actor.trust_level}."
      },
      %{
        title: "Signed events",
        body:
          "Signing key reference is registered; cryptographic verification lands after Phase 0."
      }
    ]
  end

  defp review_items(pr) do
    Enum.map(pr.reviews, fn review ->
      %{title: review.status, body: review.summary || "Review recorded."}
    end)
    |> then(fn items ->
      if items == [],
        do: [%{title: "Human review required", body: "No approving review has been recorded."}],
        else: items
    end)
  end

  defp merge_items(nil) do
    [%{title: "No merge candidate", body: "Merge metadata has not been created for this PR yet."}]
  end

  defp merge_items(candidate) do
    [
      %{
        title: "Status #{candidate.status}",
        body: "Virtual tree #{candidate.virtual_merge_tree_hash || "not computed"}."
      },
      %{
        title: "Tree equivalence",
        body:
          "tested=#{candidate.tested_tree_hash || "missing"} final=#{candidate.final_merge_tree_hash || "pending"}"
      }
    ]
  end

  defp rollback_items(nil), do: [%{title: "Not generated", body: "No rollback plan exists yet."}]

  defp rollback_items(candidate) do
    candidate.rollback_plan
    |> Enum.map(fn {key, value} -> %{title: to_string(key), body: inspect(value)} end)
  end
end
