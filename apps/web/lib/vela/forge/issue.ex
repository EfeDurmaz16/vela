defmodule Vela.Forge.Issue do
  use Vela.Schema

  @statuses ~w(open closed)
  @priorities ~w(low medium high critical)

  schema "issues" do
    field :title, :string
    field :body, :string
    field :status, :string, default: "open"
    field :priority, :string, default: "medium"
    field :labels, {:array, :string}, default: []

    belongs_to :repository, Vela.Forge.Repository
    belongs_to :author_actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [:repository_id, :author_actor_id, :title, :body, :status, :priority, :labels])
    |> validate_required([:repository_id, :author_actor_id, :title, :status, :priority])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> Vela.Validation.validate_inclusion(:priority, @priorities)
  end
end
