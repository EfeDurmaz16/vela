defmodule Vela.StateMachine do
  @moduledoc """
  Shared state-machine contracts for trust-critical Vela resources.
  """

  @machines %{
    change: %{
      "draft" => ~w(ready),
      "ready" => ~w(reviewing blocked),
      "reviewing" => ~w(blocked approved),
      "blocked" => ~w(ready reviewing),
      "approved" => ~w(merged),
      "merged" => ~w(released rolled_back),
      "released" => ~w(rolled_back),
      "rolled_back" => []
    },
    agent_session: %{
      "active" => ~w(completed failed cancelled blocked),
      "completed" => [],
      "failed" => [],
      "cancelled" => [],
      "blocked" => []
    },
    analysis_run: %{
      "queued" => ~w(running cancelled),
      "running" => ~w(completed failed cancelled),
      "completed" => [],
      "failed" => [],
      "cancelled" => []
    },
    merge_candidate: %{
      "pending" => ~w(simulating queued),
      "queued" => ~w(merging blocked cancelled),
      "simulating" => ~w(testing blocked failed),
      "testing" => ~w(ready blocked failed),
      "ready" => ~w(merging blocked),
      "blocked" => ~w(simulating),
      "merging" => ~w(merged failed),
      "merged" => [],
      "cancelled" => [],
      "failed" => []
    },
    release_candidate: %{
      "draft" => ~w(evaluating),
      "evaluating" => ~w(ready blocked),
      "ready" => ~w(launching blocked),
      "blocked" => ~w(evaluating),
      "launching" => ~w(launched rolled_back),
      "launched" => ~w(rolled_back),
      "rolled_back" => []
    }
  }

  def allowed?(machine, from, to), do: to in Map.get(transitions(machine), from, [])
  def transitions(machine), do: Map.get(@machines, machine, %{})
  def states(machine), do: machine |> transitions() |> Map.keys()
end
