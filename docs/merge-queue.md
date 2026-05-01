# Merge Queue

Vela Merge is designed around correctness, not convenience.

The invariant is: the exact tree that was tested must be the exact tree that lands.

Merge candidates move through `pending`, `simulating`, `testing`, `blocked`, `ready`, `merging`, `merged`, `failed` and `cancelled`. A candidate stores base SHA, head SHA, virtual merge SHA, virtual tree hash, tested tree hash, final tree hash, policy result and rollback plan.

If the base branch changes, the candidate must be invalidated or replayed. If final tree hash differs from tested tree hash, merge must block. Phase 0 validates metadata and renders the invariant; later Rust services perform real simulation and signed commits.
