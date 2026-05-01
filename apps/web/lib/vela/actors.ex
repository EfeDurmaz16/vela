defmodule Vela.Actors do
  @moduledoc """
  Unified actor registry for humans, agents, runners, integrations, scanners, and systems.
  """

  import Ecto.Query

  alias Vela.Actors.Actor
  alias Vela.Repo

  def create_actor(attrs), do: %Actor{} |> Actor.changeset(attrs) |> Repo.insert()

  def list_actors(organization_id) do
    Actor
    |> where([a], a.organization_id == ^organization_id)
    |> order_by([a], asc: a.display_name)
    |> Repo.all()
  end

  def list_machine_actors do
    Actor
    |> where([a], a.type in ["agent", "system", "runner", "security_scanner", "deployment_bot"])
    |> preload([:organization, :agent_identity, :agent_policies])
    |> order_by([a], asc: a.display_name)
    |> Repo.all()
  end

  def get_actor!(id),
    do:
      Actor
      |> Repo.get!(id)
      |> Repo.preload([:organization, :agent_identity, :agent_policies, :agent_sessions])
end
