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
    assert Ecto.Changeset.get_field(changeset, :can_merge) == false
  end
end
