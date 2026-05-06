defmodule Vela.Forge do
  @moduledoc """
  Repository, pull request, issue, review, and branch query surface.
  """

  import Ecto.Query

  alias Vela.Forge.{
    Branch,
    Change,
    Issue,
    PullRequest,
    Repositories,
    Repository,
    RepositoryTrustSignal,
    Review
  }

  alias Vela.Repo

  def create_repository(attrs), do: Repositories.create(attrs)

  def update_repository(%Repository{} = repository, attrs),
    do: Repositories.update(repository, attrs)

  def delete_repository(%Repository{} = repository), do: Repositories.delete(repository)

  def get_repository_for_org(organization_id, id),
    do: Repositories.get_for_org(organization_id, id)

  def get_repository_by_slug_for_org(organization_id, slug) do
    Repositories.get_by_slug_for_org(organization_id, slug)
  end

  def create_branch(attrs), do: %Branch{} |> Branch.changeset(attrs) |> Repo.insert()
  def create_change(attrs), do: %Change{} |> Change.changeset(attrs) |> Repo.insert()

  def create_pull_request(attrs),
    do: %PullRequest{} |> PullRequest.changeset(attrs) |> Repo.insert()

  def update_pull_request(%PullRequest{} = pr, attrs),
    do: pr |> PullRequest.changeset(attrs) |> Repo.update()

  def upsert_pull_request_by_provider(repository_id, provider, external_number, attrs) do
    query =
      from pr in PullRequest,
        where:
          pr.repository_id == ^repository_id and pr.provider == ^provider and
            pr.external_number == ^external_number

    case Repo.one(query) do
      nil ->
        create_pull_request(Map.merge(attrs, %{repository_id: repository_id, provider: provider}))

      pr ->
        update_pull_request(pr, attrs)
    end
  end

  def get_pull_request_for_org(organization_id, id) do
    PullRequest
    |> join(:inner, [pr], r in assoc(pr, :repository))
    |> where([pr, r], r.organization_id == ^organization_id and pr.id == ^id)
    |> preload([:repository])
    |> Repo.one()
  end

  def create_review(attrs), do: %Review{} |> Review.changeset(attrs) |> Repo.insert()
  def create_issue(attrs), do: %Issue{} |> Issue.changeset(attrs) |> Repo.insert()

  def create_repository_trust_signal(attrs),
    do: %RepositoryTrustSignal{} |> RepositoryTrustSignal.changeset(attrs) |> Repo.insert()

  def list_changes do
    Change
    |> preload([:organization, :repository, :author_actor])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def list_repositories, do: Repositories.list()

  def list_repository_trust_signals(repository_id) do
    RepositoryTrustSignal
    |> where([s], s.repository_id == ^repository_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def latest_repository_trust_signal(repository_id) do
    RepositoryTrustSignal
    |> where([s], s.repository_id == ^repository_id)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def count_open_pull_requests(repository_id) do
    PullRequest
    |> where([pr], pr.repository_id == ^repository_id)
    |> where([pr], pr.status in ["open", "ready_for_review", "blocked", "approved", "queued"])
    |> Repo.aggregate(:count)
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

  def get_repository_by_slugs!(org_slug, repo_slug),
    do: Repositories.get_by_slugs!(org_slug, repo_slug)

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
