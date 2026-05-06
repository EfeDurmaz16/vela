defmodule Vela.Forge.PullRequests do
  @moduledoc """
  Pull request write and read operations for the forge domain.
  """

  import Ecto.Query

  alias Vela.Forge.PullRequest
  alias Vela.Repo

  def create(attrs), do: %PullRequest{} |> PullRequest.changeset(attrs) |> Repo.insert()

  def update(%PullRequest{} = pull_request, attrs),
    do: pull_request |> PullRequest.changeset(attrs) |> Repo.update()

  def upsert_by_provider(repository_id, provider, external_number, attrs) do
    now = DateTime.utc_now(:second)

    attrs =
      attrs
      |> Map.merge(%{
        repository_id: repository_id,
        provider: provider,
        external_number: external_number
      })

    %PullRequest{}
    |> PullRequest.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          author_actor_id: attrs.author_actor_id,
          title: attrs.title,
          description: attrs.description,
          source_branch: attrs.source_branch,
          target_branch: attrs.target_branch,
          head_sha: attrs.head_sha,
          base_sha: attrs.base_sha,
          status: attrs.status,
          external_id: attrs.external_id,
          html_url: attrs.html_url,
          updated_at: now
        ]
      ],
      conflict_target: [:repository_id, :provider, :external_number],
      returning: true
    )
  end

  def get_for_org(organization_id, id) do
    PullRequest
    |> join(:inner, [pr], r in assoc(pr, :repository))
    |> where([pr, r], r.organization_id == ^organization_id and pr.id == ^id)
    |> preload([:repository])
    |> Repo.one()
  end

  def count_open(repository_id) do
    PullRequest
    |> where([pr], pr.repository_id == ^repository_id)
    |> where([pr], pr.status in ["open", "ready_for_review", "blocked", "approved", "queued"])
    |> Repo.aggregate(:count)
  end

  def list do
    PullRequest
    |> preload([:author_actor, :readiness_scores, :merge_candidates, repository: :organization])
    |> order_by([pr], desc: pr.inserted_at)
    |> Repo.all()
  end

  def active(limit \\ 6) do
    PullRequest
    |> where([pr], pr.status in ["open", "ready_for_review", "blocked", "approved", "queued"])
    |> preload([:author_actor, :readiness_scores, :merge_candidates, repository: :organization])
    |> order_by([pr], desc: pr.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_for_route!(org_slug, repo_slug, id) do
    PullRequest
    |> join(:inner, [pr], r in assoc(pr, :repository))
    |> join(:inner, [pr, r], o in assoc(r, :organization))
    |> where([pr, r, o], o.slug == ^org_slug and r.slug == ^repo_slug and pr.id == ^id)
    |> preload([
      :author_actor,
      :files,
      :reviews,
      :readiness_scores,
      :merge_candidates,
      repository: [:organization]
    ])
    |> Repo.one!()
  end

  def latest_score(%PullRequest{readiness_scores: []}) do
    %{
      verdict: "unknown",
      overall_score: 0,
      behavioral_score: 0,
      correctness_score: 0,
      security_score: 0,
      performance_score: 0,
      ux_score: 0,
      test_evidence_score: 0,
      agent_provenance_score: 0,
      explanation: "No readiness score has been recorded for this pull request yet.",
      blocking_findings: [],
      required_actions: ["Run analysis before treating this pull request as queue-ready."]
    }
  end

  def latest_score(%PullRequest{readiness_scores: scores}) do
    Enum.max_by(scores, & &1.inserted_at, DateTime)
  end

  def latest_merge_candidate(%PullRequest{merge_candidates: []}), do: nil

  def latest_merge_candidate(%PullRequest{merge_candidates: candidates}) do
    Enum.max_by(candidates, & &1.inserted_at, DateTime)
  end
end
