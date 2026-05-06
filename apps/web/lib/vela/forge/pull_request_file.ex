defmodule Vela.Forge.PullRequestFile do
  use Vela.Schema

  @statuses ~w(added removed modified renamed copied changed unchanged)

  schema "pull_request_files" do
    field :path, :string
    field :previous_path, :string
    field :status, :string
    field :additions, :integer, default: 0
    field :deletions, :integer, default: 0
    field :changes, :integer, default: 0
    field :patch, :string
    field :blob_url, :string
    field :raw_url, :string

    belongs_to :pull_request, Vela.Forge.PullRequest

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(file, attrs) do
    file
    |> cast(attrs, [
      :pull_request_id,
      :path,
      :previous_path,
      :status,
      :additions,
      :deletions,
      :changes,
      :patch,
      :blob_url,
      :raw_url
    ])
    |> validate_required([:pull_request_id, :path, :status, :additions, :deletions, :changes])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_number(:additions, greater_than_or_equal_to: 0)
    |> validate_number(:deletions, greater_than_or_equal_to: 0)
    |> validate_number(:changes, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:pull_request_id)
    |> unique_constraint([:pull_request_id, :path])
  end
end
