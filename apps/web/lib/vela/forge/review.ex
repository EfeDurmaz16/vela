defmodule Vela.Forge.Review do
  use Vela.Schema

  @statuses ~w(comment approve request_changes block)

  schema "reviews" do
    field :status, :string
    field :summary, :string

    belongs_to :pull_request, Vela.Forge.PullRequest
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:pull_request_id, :actor_id, :status, :summary])
    |> validate_required([:pull_request_id, :actor_id, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
  end
end
