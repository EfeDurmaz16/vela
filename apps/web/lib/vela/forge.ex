defmodule Vela.Forge do
  @moduledoc """
  Repository, pull request, issue, review, and branch query surface.
  """

  import Ecto.Query

  alias Vela.Forge.{Branch, Issue, PullRequest, Repository, Review}
  alias Vela.Repo

  def create_repository(attrs), do: %Repository{} |> Repository.changeset(attrs) |> Repo.insert()
  def create_branch(attrs), do: %Branch{} |> Branch.changeset(attrs) |> Repo.insert()

  def create_pull_request(attrs),
    do: %PullRequest{} |> PullRequest.changeset(attrs) |> Repo.insert()

  def update_pull_request(%PullRequest{} = pr, attrs),
    do: pr |> PullRequest.changeset(attrs) |> Repo.update()

  def create_review(attrs), do: %Review{} |> Review.changeset(attrs) |> Repo.insert()
  def create_issue(attrs), do: %Issue{} |> Issue.changeset(attrs) |> Repo.insert()

  def list_repositories do
    Repository
    |> preload([:organization, :pull_requests])
    |> order_by([r], asc: r.name)
    |> Repo.all()
  end

  def list_pull_requests do
    PullRequest
    |> preload([:author_actor, :readiness_scores, :merge_candidates, repository: :organization])
    |> order_by([pr], desc: pr.inserted_at)
    |> Repo.all()
  end

  def active_pull_requests(limit \\ 6) do
    PullRequest
    |> where([pr], pr.status in ["open", "ready_for_review", "blocked", "approved", "queued"])
    |> preload([:author_actor, :readiness_scores, :merge_candidates, repository: :organization])
    |> order_by([pr], desc: pr.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_repository_by_slugs!(org_slug, repo_slug) do
    Repository
    |> join(:inner, [r], o in assoc(r, :organization))
    |> where([r, o], o.slug == ^org_slug and r.slug == ^repo_slug)
    |> preload([
      :organization,
      :branches,
      pull_requests: [
        :author_actor,
        :readiness_scores,
        :merge_candidates,
        repository: :organization
      ]
    ])
    |> Repo.one!()
  end

  def get_pull_request_for_route!(org_slug, repo_slug, id) do
    PullRequest
    |> join(:inner, [pr], r in assoc(pr, :repository))
    |> join(:inner, [pr, r], o in assoc(r, :organization))
    |> where([pr, r, o], o.slug == ^org_slug and r.slug == ^repo_slug and pr.id == ^id)
    |> preload([
      :author_actor,
      :reviews,
      :readiness_scores,
      :merge_candidates,
      repository: [:organization]
    ])
    |> Repo.one!()
  end

  def latest_score(%PullRequest{readiness_scores: scores}) do
    Enum.max_by(scores, & &1.inserted_at, DateTime)
  end

  def latest_merge_candidate(%PullRequest{merge_candidates: candidates}) do
    Enum.max_by(candidates, & &1.inserted_at, DateTime)
  end
end
