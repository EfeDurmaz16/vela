defmodule Vela.Forge.Reviews do
  @moduledoc """
  Pull request review operations for the forge domain.
  """

  alias Vela.Forge.Review
  alias Vela.Repo

  def create(attrs), do: %Review{} |> Review.changeset(attrs) |> Repo.insert()
end
