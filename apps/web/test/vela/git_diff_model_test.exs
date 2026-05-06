defmodule Vela.GitDiffModelTest do
  use ExUnit.Case, async: true

  alias Vela.Git.DiffModel

  test "normalizes GitHub changed-file payloads into provider-neutral attrs" do
    assert %{
             path: "apps/web/lib/core.ex",
             previous_path: "apps/web/lib/old_core.ex",
             status: "renamed",
             blob_sha: "abc123",
             additions: 10,
             deletions: 2,
             changes: 12,
             patch: "@@ patch",
             blob_url: "https://github.test/blob",
             raw_url: "https://github.test/raw"
           } =
             DiffModel.github_file_attrs(%{
               "filename" => "apps/web/lib/core.ex",
               "previous_filename" => "apps/web/lib/old_core.ex",
               "status" => "renamed",
               "sha" => "abc123",
               "additions" => 10,
               "deletions" => 2,
               "changes" => 12,
               "patch" => "@@ patch",
               "blob_url" => "https://github.test/blob",
               "raw_url" => "https://github.test/raw"
             })
  end

  test "falls back unknown provider statuses to changed" do
    assert %{status: "changed"} =
             DiffModel.github_file_attrs(%{
               "filename" => "README.md",
               "status" => "uncharted",
               "sha" => "abc123",
               "patch" => "@@ patch"
             })
  end

  test "validates path sha counters and textual patch requirements" do
    assert {:ok, attrs} =
             DiffModel.validate(%{
               path: "README.md",
               status: "modified",
               blob_sha: "abc123",
               additions: 1,
               deletions: 0,
               changes: 1,
               patch: "@@ patch"
             })

    assert attrs.path == "README.md"

    assert {:error, changeset} =
             DiffModel.validate(%{
               path: "",
               status: "modified",
               additions: -1,
               deletions: 0,
               changes: 1
             })

    assert "can't be blank" in errors_on(changeset).path
    assert "can't be blank" in errors_on(changeset).blob_sha
    assert "can't be blank for textual changed files" in errors_on(changeset).patch
    assert "must be greater than or equal to 0" in errors_on(changeset).additions
  end

  test "allows deleted and unchanged files without patch bodies" do
    assert {:ok, _attrs} =
             DiffModel.validate(%{
               path: "deleted.ex",
               status: "removed",
               additions: 0,
               deletions: 8,
               changes: 8
             })

    assert {:ok, _attrs} =
             DiffModel.validate(%{
               path: "binary.png",
               status: "unchanged",
               blob_sha: "abc123",
               additions: 0,
               deletions: 0,
               changes: 0
             })
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
