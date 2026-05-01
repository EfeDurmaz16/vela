defmodule Vela.MergeTest do
  use Vela.DataCase, async: true

  alias Vela.Merge
  alias Vela.Merge.MergeCandidate

  test "validates allowed state transitions" do
    assert Merge.allowed_transition?("pending", "simulating")
    assert Merge.allowed_transition?("simulating", "testing")
    assert Merge.allowed_transition?("testing", "ready")
    refute Merge.allowed_transition?("pending", "merged")
  end

  test "blocks ready or merged tree mismatches" do
    changeset =
      MergeCandidate.changeset(%MergeCandidate{}, %{
        repository_id: Ecto.UUID.generate(),
        pull_request_id: Ecto.UUID.generate(),
        base_sha: "base",
        head_sha: "head",
        status: "ready",
        tested_tree_hash: "tree:a",
        final_merge_tree_hash: "tree:b"
      })

    refute changeset.valid?
    assert {"must match tested_tree_hash", _} = changeset.errors[:final_merge_tree_hash]
  end
end
