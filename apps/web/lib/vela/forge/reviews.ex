defmodule Vela.Forge.Reviews do
  @moduledoc """
  Pull request review operations for the forge domain.
  """

  alias Vela.Forge.Review
  alias Vela.Repo

  def create(attrs), do: %Review{} |> Review.changeset(attrs) |> Repo.insert()

  def upsert_by_provider(pull_request_id, provider, external_id, attrs) do
    attrs =
      attrs
      |> Map.put(:pull_request_id, pull_request_id)
      |> Map.put(:provider, provider)
      |> Map.put(:external_id, to_string(external_id))

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [
          actor_id: attrs.actor_id,
          status: attrs.status,
          summary: attrs.summary,
          external_author_login: attrs.external_author_login,
          submitted_at: attrs.submitted_at,
          updated_at: DateTime.utc_now(:second)
        ]
      ],
      conflict_target: [:pull_request_id, :provider, :external_id]
    )
  end
end
