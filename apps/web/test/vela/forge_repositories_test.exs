defmodule Vela.Forge.RepositoriesTest do
  use Vela.DataCase, async: true

  alias Vela.Accounts
  alias Vela.Forge.Repositories

  test "get_for_org returns only repositories in the supplied organization" do
    {:ok, org} = Accounts.create_organization(%{name: "Repo Tenant A", slug: "repo-tenant-a"})

    {:ok, other_org} =
      Accounts.create_organization(%{name: "Repo Tenant B", slug: "repo-tenant-b"})

    {:ok, repo} = repository_fixture!(org, "core")
    {:ok, other_repo} = repository_fixture!(other_org, "core")

    assert Repositories.get_for_org(org.id, repo.id).id == repo.id
    assert Repositories.get_for_org(org.id, other_repo.id) == nil
  end

  test "get_by_slug_for_org scopes slug lookup to the organization" do
    {:ok, org} = Accounts.create_organization(%{name: "Repo Slug A", slug: "repo-slug-a"})
    {:ok, other_org} = Accounts.create_organization(%{name: "Repo Slug B", slug: "repo-slug-b"})

    {:ok, repo} = repository_fixture!(org, "shared")
    {:ok, other_repo} = repository_fixture!(other_org, "shared")

    assert Repositories.get_by_slug_for_org(org.id, "shared").id == repo.id
    assert Repositories.get_by_slug_for_org(other_org.id, "shared").id == other_repo.id
  end

  defp repository_fixture!(org, slug) do
    Repositories.create(%{
      organization_id: org.id,
      name: "Repo #{slug}",
      slug: slug,
      visibility: "private",
      default_branch: "main",
      health_status: "healthy",
      risk_level: "low"
    })
  end
end
