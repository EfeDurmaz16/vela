# Merge Queue

Vela Merge is designed around correctness, not convenience.

The invariant is: the exact tree that was tested must be the exact tree that lands.

Merge candidates move through `pending`, `queued`, `simulating`, `testing`, `blocked`, `ready`, `merging`, `merged` and `failed`. A candidate stores base SHA, head SHA, virtual merge SHA, virtual tree hash, tested tree hash, final tree hash, policy result and rollback plan.

Phase 0 can queue a pull request for merge only after a passing review gate and readiness gate. The review gate requires at least one `approve` review and no `request_changes` or `block` review. The readiness gate requires the latest repository readiness verdict to be `ship`. Queueing records a `merge.queued` evidence event and a pending outbox event before later merge execution work is allowed.

If the base branch changes, the candidate must be invalidated or replayed. If final tree hash differs from tested tree hash, merge must block. Phase 0 validates metadata and renders the invariant; later Rust services perform real simulation and signed commits.
