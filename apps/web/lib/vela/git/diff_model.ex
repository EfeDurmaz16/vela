defmodule Vela.Git.DiffModel do
  @moduledoc """
  Provider-agnostic changed-file representation.

  Git providers expose similar changed-file concepts with different field names
  and edge cases. This module is the normalization boundary before persistence
  or readiness analysis consumes file-level diff data.
  """

  import Ecto.Changeset

  @statuses ~w(added removed modified renamed copied changed unchanged)
  @patch_required_statuses ~w(added modified renamed copied changed)

  @types %{
    path: :string,
    previous_path: :string,
    status: :string,
    blob_sha: :string,
    additions: :integer,
    deletions: :integer,
    changes: :integer,
    patch: :string,
    blob_url: :string,
    raw_url: :string
  }

  def statuses, do: @statuses

  def github_file_attrs(file) do
    %{
      path: file["filename"],
      previous_path: file["previous_filename"],
      status: normalize_status(file["status"]),
      blob_sha: file["sha"],
      additions: file["additions"] || 0,
      deletions: file["deletions"] || 0,
      changes: file["changes"] || 0,
      patch: file["patch"],
      blob_url: file["blob_url"],
      raw_url: file["raw_url"]
    }
  end

  def validate(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required([:path, :status, :additions, :deletions, :changes])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_number(:additions, greater_than_or_equal_to: 0)
    |> validate_number(:deletions, greater_than_or_equal_to: 0)
    |> validate_number(:changes, greater_than_or_equal_to: 0)
    |> validate_blob_sha()
    |> validate_patch_presence()
    |> apply_action(:validate)
  end

  defp validate_blob_sha(changeset) do
    case get_field(changeset, :status) do
      "removed" -> changeset
      _ -> validate_required(changeset, [:blob_sha])
    end
  end

  defp validate_patch_presence(changeset) do
    status = get_field(changeset, :status)
    patch = get_field(changeset, :patch)

    if status in @patch_required_statuses and blank?(patch) do
      add_error(changeset, :patch, "can't be blank for textual changed files")
    else
      changeset
    end
  end

  defp blank?(value), do: !is_binary(value) or String.trim(value) == ""

  defp normalize_status(status) when status in @statuses, do: status
  defp normalize_status(_status), do: "changed"
end
