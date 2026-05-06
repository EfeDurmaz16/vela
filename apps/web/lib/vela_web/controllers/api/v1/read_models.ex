defmodule VelaWeb.Api.V1.ReadModels do
  @moduledoc """
  Read-side collection queries for the v1 JSON API.
  """

  import Ecto.Query

  alias Vela.Repo

  def analysis_runs do
    Vela.Maestro.AnalysisRun
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def readiness_scores do
    Vela.Maestro.ReadinessScore
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def merge_candidates do
    Vela.Merge.MergeCandidate
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def releases do
    Vela.Releases.ReleaseCandidate
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def change_readiness(change_id) do
    Vela.Maestro.ReadinessScore
    |> where([s], s.change_id == ^change_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def agent_sessions(agent_actor_id) do
    Vela.Agents.AgentSession
    |> where([s], s.agent_actor_id == ^agent_actor_id)
    |> order_by([s], desc: s.started_at)
    |> Repo.all()
  end

  def agent_policies(actor_id) do
    Vela.Agents.AgentPolicy
    |> where([p], p.actor_id == ^actor_id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end
end
