defmodule Vela.Releases do
  @moduledoc """
  Release candidate metadata and state transitions.
  """

  alias Vela.Releases.ReleaseCandidate
  alias Vela.Repo
  alias Vela.StateMachine

  def create_release_candidate(attrs),
    do: %ReleaseCandidate{} |> ReleaseCandidate.changeset(attrs) |> Repo.insert()

  def transition(%ReleaseCandidate{} = candidate, next_status, attrs \\ %{}) do
    if StateMachine.allowed?(:release_candidate, candidate.status, next_status) do
      candidate
      |> ReleaseCandidate.changeset(Map.put(attrs, :status, next_status))
      |> Repo.update()
    else
      {:error, {:invalid_transition, candidate.status, next_status}}
    end
  end
end
