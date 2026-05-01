defmodule Vela.Agents do
  @moduledoc """
  Agent identity, sessions, permissions, and provenance queries.
  """

  import Ecto.Query

  alias Vela.Actors.Actor
  alias Vela.Agents.{AgentIdentity, AgentPolicy, AgentSession}
  alias Vela.Repo

  def create_agent_identity(attrs),
    do: %AgentIdentity{} |> AgentIdentity.changeset(attrs) |> Repo.insert()

  def create_agent_policy(attrs),
    do: %AgentPolicy{} |> AgentPolicy.changeset(attrs) |> Repo.insert()

  def create_agent_session(attrs),
    do: %AgentSession{} |> AgentSession.changeset(attrs) |> Repo.insert()

  def list_agent_profiles do
    Actor
    |> where([a], a.type == "agent")
    |> preload([
      :organization,
      :agent_identity,
      :agent_policies,
      agent_sessions: [:repository, :human_supervisor]
    ])
    |> order_by([a], asc: a.display_name)
    |> Repo.all()
  end

  def get_agent_profile!(id) do
    Actor
    |> where([a], a.id == ^id and a.type == "agent")
    |> preload([
      :organization,
      :agent_identity,
      :agent_policies,
      agent_sessions: [:repository, :human_supervisor]
    ])
    |> Repo.one!()
  end

  def list_recent_sessions(limit \\ 5) do
    AgentSession
    |> preload([:repository, :agent_actor, :human_supervisor])
    |> order_by([s], desc: s.started_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
