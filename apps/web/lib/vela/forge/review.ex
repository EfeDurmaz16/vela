defmodule Vela.Forge.Review do
  use Vela.Schema

  @statuses ~w(comment approve request_changes block)

  schema "reviews" do
    field :status, :string
    field :summary, :string
    field :provider, :string
    field :external_id, :string
    field :external_author_login, :string
    field :submitted_at, :utc_datetime

    belongs_to :pull_request, Vela.Forge.PullRequest
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :pull_request_id,
      :actor_id,
      :status,
      :summary,
      :provider,
      :external_id,
      :external_author_login,
      :submitted_at
    ])
    |> validate_required([:pull_request_id, :actor_id, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint([:pull_request_id, :provider, :external_id])
  end
end
