defmodule Vela.Forge.TrustSignals do
  @moduledoc """
  Repository trust signal operations for the forge domain.
  """

  import Ecto.Query

  alias Vela.Forge.RepositoryTrustSignal
  alias Vela.Repo

  def create(attrs),
    do: %RepositoryTrustSignal{} |> RepositoryTrustSignal.changeset(attrs) |> Repo.insert()

  def list_for_repository(repository_id) do
    RepositoryTrustSignal
    |> where([s], s.repository_id == ^repository_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def latest_for_repository(repository_id) do
    RepositoryTrustSignal
    |> where([s], s.repository_id == ^repository_id)
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
