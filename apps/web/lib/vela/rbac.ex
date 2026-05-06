defmodule Vela.RBAC do
  @moduledoc """
  Role-based access checks for human WorkOS-authenticated memberships.
  """

  alias Vela.Accounts.Membership

  @permissions %{
    "owner" => :all,
    "admin" => :all,
    "maintainer" => [
      {:repository, :create},
      {:repository, :import},
      {:repository, :sync_pull_request},
      {:repository, :update},
      {:change, :update},
      {:pull_request, :update},
      {:review, :create},
      {:merge_candidate, :simulate},
      {:release_candidate, :create},
      {:agent_policy, :update}
    ],
    "developer" => [
      {:change, :create},
      {:change, :update},
      {:pull_request, :create},
      {:pull_request, :update},
      {:analysis_run, :create}
    ],
    "reviewer" => [
      {:review, :create},
      {:readiness_score, :read},
      {:evidence_event, :read}
    ],
    "observer" => [
      {:organization, :read},
      {:repository, :read},
      {:change, :read},
      {:pull_request, :read},
      {:readiness_score, :read},
      {:evidence_event, :read}
    ]
  }

  def allowed?(%Membership{role: role}, resource, action) do
    case Map.get(@permissions, role, []) do
      :all ->
        true

      permissions ->
        {resource, action} in permissions or
          ({resource, :read} in permissions and action == :read)
    end
  end

  def allowed?(_, _, _), do: false
end
