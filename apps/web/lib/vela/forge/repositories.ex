defmodule Vela.Forge.Repositories do
  @moduledoc """
  Repository write and read operations for the forge domain.
  """

  import Ecto.Query

  alias Vela.Forge.Repository
  alias Vela.Repo

  def create(attrs), do: %Repository{} |> Repository.changeset(attrs) |> Repo.insert()

  def update(%Repository{} = repository, attrs),
    do: repository |> Repository.changeset(attrs) |> Repo.update()

  def delete(%Repository{} = repository), do: Repo.delete(repository)

  def get_for_org(organization_id, id) do
    Repository
    |> where([r], r.organization_id == ^organization_id and r.id == ^id)
    |> Repo.one()
  end

  def get_by_slug_for_org(organization_id, slug) do
    Repository
    |> where([r], r.organization_id == ^organization_id and r.slug == ^slug)
    |> Repo.one()
  end

  def list do
    Repository
    |> preload([:organization, :pull_requests])
    |> order_by([r], asc: r.name)
    |> Repo.all()
  end

  def get_by_slugs!(org_slug, repo_slug) do
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
end
