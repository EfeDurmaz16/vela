defmodule Vela.StateMachineTest do
  use ExUnit.Case, async: true

  alias Vela.StateMachine

  test "change transitions match the trust workflow" do
    assert StateMachine.allowed?(:change, "draft", "ready")
    assert StateMachine.allowed?(:change, "approved", "merged")
    assert StateMachine.allowed?(:change, "released", "rolled_back")
    refute StateMachine.allowed?(:change, "draft", "merged")
  end

  test "agent session transitions are terminal after completion states" do
    assert StateMachine.allowed?(:agent_session, "active", "completed")
    assert StateMachine.allowed?(:agent_session, "active", "blocked")
    refute StateMachine.allowed?(:agent_session, "completed", "active")
  end

  test "analysis, merge, and release candidate transitions are explicit" do
    assert StateMachine.allowed?(:analysis_run, "queued", "running")
    assert StateMachine.allowed?(:analysis_run, "running", "completed")
    assert StateMachine.allowed?(:merge_candidate, "pending", "simulating")
    assert StateMachine.allowed?(:merge_candidate, "testing", "blocked")
    assert StateMachine.allowed?(:release_candidate, "draft", "evaluating")
    assert StateMachine.allowed?(:release_candidate, "launching", "launched")
    refute StateMachine.allowed?(:release_candidate, "draft", "launched")
  end
end
