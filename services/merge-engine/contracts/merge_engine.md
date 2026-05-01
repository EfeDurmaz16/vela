# Merge Engine Contract

Methods:

- `CreateMergeCandidate(repo_id, pull_request_id, base_sha, head_sha)`
- `SimulateMerge(candidate_id)`
- `CompareTreeHashes(tested_tree_hash, final_tree_hash)`
- `GenerateRollbackPlan(candidate_id)`
- `SignMergeCommit(candidate_id, actor_id)`

Invariant: tested tree hash must equal final merge tree hash.
