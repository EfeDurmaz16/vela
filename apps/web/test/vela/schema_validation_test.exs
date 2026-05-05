defmodule Vela.SchemaValidationTest do
  use Vela.DataCase, async: true

  alias Vela.Accounts.{Membership, Organization, User}
  alias Vela.Actors.Actor
  alias Vela.Agents.{AgentIdentity, AgentPolicy}
  alias Vela.Forge.{PullRequest, Repository}
  alias Vela.Maestro.LaunchReadinessScore
  alias Vela.Merge.MergeCandidate

  test "core changesets validate required enum-like fields" do
    assert %{valid?: false} = Organization.changeset(%Organization{}, %{})
    assert %{valid?: false} = User.changeset(%User{}, %{email: "bad", name: "Efe"})
    assert %{valid?: false} = Membership.changeset(%Membership{}, %{role: "root"})
    assert %{valid?: false} = Actor.changeset(%Actor{}, %{type: "bot", trust_level: "trusted"})
    assert %{valid?: false} = Repository.changeset(%Repository{}, %{visibility: "secret"})
    assert %{valid?: false} = PullRequest.changeset(%PullRequest{}, %{status: "reviewing"})

    assert %{valid?: false} =
             LaunchReadinessScore.changeset(%LaunchReadinessScore{}, %{verdict: "maybe"})

    assert %{valid?: false} = MergeCandidate.changeset(%MergeCandidate{}, %{status: "done"})
  end

  test "agent identity trust score and policy defaults are bounded" do
    assert %{valid?: false} =
             AgentIdentity.changeset(%AgentIdentity{}, %{
               actor_id: Ecto.UUID.generate(),
               trust_score: 101,
               status: "active"
             })

    changeset =
      AgentPolicy.changeset(%AgentPolicy{}, %{
        organization_id: Ecto.UUID.generate(),
        actor_id: Ecto.UUID.generate(),
        name: "Test agent"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :requires_human_approval) == true
    assert Ecto.Changeset.get_field(changeset, :can_create_pr) == false
    assert Ecto.Changeset.get_field(changeset, :can_merge) == false
  end

  test "repository schema stores provider import metadata" do
    imported_at = DateTime.utc_now(:second)

    changeset =
      Repository.changeset(%Repository{}, %{
        organization_id: Ecto.UUID.generate(),
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low",
        provider: "github",
        external_id: "42",
        full_name: "vela/core",
        html_url: "https://github.com/vela/core",
        import_status: "imported",
        imported_at: imported_at
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :provider) == "github"
    assert Ecto.Changeset.get_field(changeset, :import_status) == "imported"
    assert Ecto.Changeset.get_field(changeset, :imported_at) == imported_at
  end

  test "pull request schema stores provider metadata for GitHub operations" do
    changeset =
      PullRequest.changeset(%PullRequest{}, %{
        repository_id: Ecto.UUID.generate(),
        author_actor_id: Ecto.UUID.generate(),
        title: "Change",
        source_branch: "feature",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review",
        provider: "github",
        external_id: "987",
        external_number: 17,
        html_url: "https://github.com/vela/core/pull/17"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :provider) == "github"
    assert Ecto.Changeset.get_field(changeset, :external_number) == 17
  end
end
