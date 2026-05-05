defmodule Vela.RBACTest do
  use ExUnit.Case, async: true

  alias Vela.Accounts.Membership
  alias Vela.RBAC

  test "owner and admin can mutate org resources" do
    assert RBAC.allowed?(%Membership{role: "owner"}, :repository, :create)
    assert RBAC.allowed?(%Membership{role: "admin"}, :agent_policy, :update)
  end

  test "reviewers can review but observers cannot mutate" do
    assert RBAC.allowed?(%Membership{role: "reviewer"}, :review, :create)
    refute RBAC.allowed?(%Membership{role: "observer"}, :review, :create)
    refute RBAC.allowed?(nil, :repository, :create)
  end
end
