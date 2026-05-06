# Merge Queue

Vela Merge is designed around correctness, not convenience.

The invariant is: the exact tree that was tested must be the exact tree that lands.

Merge candidates move through `pending`, `queued`, `simulating`, `testing`, `blocked`, `ready`, `merging`, `merged`, `cancelled` and `failed`. A candidate stores base SHA, head SHA, target branch, queue position, virtual merge SHA, virtual tree hash, tested tree hash, final tree hash, policy result and rollback plan.

Phase 0 can queue a pull request for merge only after every local gate passes:

- Review gate: at least one `approve` review and no `request_changes` or `block` review.
- Branch protection gate: protected target branches must have the configured approval count and all required checks passing.
- Base freshness gate: protected target branch `current_sha` must still match the pull request `base_sha`.
- Readiness gate: latest repository readiness verdict must be `ship`.
- Candidate gate: a merge candidate must exist and its state machine must allow `pending -> queued`.

Queue positions are assigned per repository and target branch. The first queued candidate for `repo/main` receives position `1`, the next receives `2`, and a separate branch starts at `1`. Cancelling a queued candidate moves it to terminal `cancelled`, clears its queue position and compacts later positions in the same repository/branch scope.

Tree equivalence is tracked separately from queue state:

- `unmerged`: no virtual merge tree exists yet.
- `untested`: a virtual merge tree exists but no tested tree is recorded.
- `tested`: a tested tree exists.
- `equivalent`: final merge tree equals the tested tree.
- `mismatch`: final merge tree differs from the tested tree and cannot become `ready` or `merged`.

Current blocking reasons are `missing_approval`, `blocking_review`, `branch_protection_missing_approvals`, `branch_protection_missing_checks`, `stale_base_sha`, `missing_readiness`, `readiness_not_ship`, `missing_merge_candidate`, invalid state transitions and final tree mismatch validation errors.

The final merge execution boundary is now modeled as an adapter contract. Vela owns queue state, gates, evidence and audit semantics; future GitHub or direct-Git adapters own the irreversible act of landing a merge. Phase 0 validates metadata and renders the invariant; later services perform real simulation, signed commits and provider-specific merge execution.
