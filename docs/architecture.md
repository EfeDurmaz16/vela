# Architecture

Vela uses Phoenix and Postgres as the canonical control plane. The initial app owns users, organizations, actors, repositories, pull requests, agent sessions, readiness scores, merge candidates, policy decisions, runners and evidence events.

The Phase 0 app is real where product state matters and mock-backed where correctness-critical services need separate runtimes:

- Phoenix LiveView renders realtime app surfaces.
- Postgres is the source of truth for control-plane data.
- Rust Git Gateway will later handle Git over SSH/HTTPS, refs and packfiles.
- Rust Merge Engine will later handle deterministic virtual merge candidates and tree equivalence.
- Python Maestro will later orchestrate analysis, test generation and readiness scoring.
- Vela Evidence stores append-only hash-chained events from day one.
- Search starts as a contract and later becomes Tantivy/Zoekt-like indexing.
- BYO runners are modeled before hosted CI exists.

The future scale model is cell-based: each cell contains Git gateway nodes, repo-engine writers/replicas, search shards, worker pools, object storage prefixes and health monitors. Phase 0 only stores `repo_cell_id` and documents this boundary.
