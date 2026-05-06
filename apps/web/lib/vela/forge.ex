defmodule Vela.Forge do
  @moduledoc """
  Repository, pull request, issue, review, and branch query surface.
  """

  import Ecto.Query

  alias Vela.Forge.{
    Branch,
    Change,
    Issue,
    PullRequests,
    PullRequest,
    Repositories,
    Repository,
    Reviews,
    TrustSignals
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

  def upsert_branch(repository_id, attrs) do
    now = DateTime.utc_now(:second)

    attrs =
      attrs
      |> Map.put(:repository_id, repository_id)
      |> Map.put_new(:protected, false)

    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          current_sha: attrs.current_sha,
          protected: attrs.protected,
          updated_at: now
        ]
      ],
      conflict_target: [:repository_id, :name]
    )
  end

  def create_change(attrs), do: %Change{} |> Change.changeset(attrs) |> Repo.insert()

  def create_pull_request(attrs), do: PullRequests.create(attrs)

  def update_pull_request(%PullRequest{} = pr, attrs),
    do: PullRequests.update(pr, attrs)

  def upsert_pull_request_by_provider(repository_id, provider, external_number, attrs) do
    PullRequests.upsert_by_provider(repository_id, provider, external_number, attrs)
  end

  def get_pull_request_for_org(organization_id, id) do
    PullRequests.get_for_org(organization_id, id)
  end

  def create_review(attrs), do: Reviews.create(attrs)
  def create_issue(attrs), do: %Issue{} |> Issue.changeset(attrs) |> Repo.insert()

  def create_repository_trust_signal(attrs), do: TrustSignals.create(attrs)

  def list_changes do
    Change
    |> preload([:organization, :repository, :author_actor])
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def list_repositories, do: Repositories.list()

  def list_repository_trust_signals(repository_id),
    do: TrustSignals.list_for_repository(repository_id)

  def latest_repository_trust_signal(repository_id) do
    TrustSignals.latest_for_repository(repository_id)
  end

  def count_open_pull_requests(repository_id), do: PullRequests.count_open(repository_id)

  def list_pull_requests, do: PullRequests.list()

  def active_pull_requests(limit \\ 6), do: PullRequests.active(limit)

  def get_repository_by_slugs!(org_slug, repo_slug),
    do: Repositories.get_by_slugs!(org_slug, repo_slug)

  def get_pull_request_for_route!(org_slug, repo_slug, id),
    do: PullRequests.get_for_route!(org_slug, repo_slug, id)

  def latest_score(%PullRequest{} = pull_request), do: PullRequests.latest_score(pull_request)

  def latest_merge_candidate(%PullRequest{} = pull_request),
    do: PullRequests.latest_merge_candidate(pull_request)
end
