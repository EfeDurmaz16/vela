# Architecture

Vela uses Phoenix and Postgres as the canonical control plane. The initial app owns organizations, users, memberships, repositories, changes, pull requests, reviews, issues, agent identities, agent sessions, agent policies, analysis runs, readiness scores, merge candidates, release candidates, evidence events, integrations, service connections, environments, repository trust signals, idempotency records and outbox events.

The Phase 0 app is real where product state matters and mock-backed where correctness-critical services need separate runtimes:

- Phoenix LiveView renders realtime app surfaces.
- Postgres is the source of truth for control-plane data.
- Oban runs expensive work outside the request path: imports, repo sync, analysis, readiness/trust scoring and merge simulation.
- PubSub is the local event bus. Outbox rows are the durable cross-service event handoff.
- Object storage is modeled as artifact/log/release references and backed locally by MinIO in development.
- Rust Git Gateway will later handle Git over SSH/HTTPS, refs and packfiles.
- Rust Merge Engine will later handle deterministic virtual merge candidates and tree equivalence.
- Python Maestro will later orchestrate analysis, test generation and readiness scoring.
- Vela Evidence stores append-only hash-chained events from day one.
- Evidence is hash-chained per repository when `repository_id` exists and per organization for org-level events.
- Human authorization is WorkOS-aligned membership RBAC. Agent identity is a separate actor/policy model.
- Search starts as a contract and later becomes Tantivy/Zoekt-like indexing.
- BYO runners are modeled before hosted CI exists.

The future scale model is cell-based: each cell contains Git gateway nodes, repo-engine writers/replicas, search shards, worker pools, object storage prefixes and health monitors. Phase 0 only stores `repo_cell_id` and documents this boundary.

## Backend Modules

- `Vela.RBAC`: owner/admin/maintainer/developer/reviewer/observer checks.
- `Vela.Policy`: fail-closed agent merge policy evaluation.
- `Vela.StateMachine`: explicit transitions for Change, AgentSession, AnalysisRun, MergeCandidate and ReleaseCandidate.
- `Vela.Evidence`: append-only event writes with canonical JSON payload hashes.
- `Vela.Jobs`: Oban constructors for expensive import, sync, analysis, scoring and simulation jobs.
- `Vela.Integrations`: adapter behavior and persisted provider/service/environment records.
- `Vela.Git.*`: behaviours for GitProvider, RepoImporter, RefService, DiffService and MergeSimulator sidecars.
- `Vela.Storage.ObjectStore`: object storage boundary for logs, artifacts, analysis outputs and releases.
- `Vela.Auth.WorkOS`: WorkOS SSO boundary for human auth.
- `Vela.Agents.SignatureVerifier`: signed agent identity verification boundary.
- `Vela.Crypto`: AES-GCM token encryption helper for integration secrets.
- `Vela.RateLimit`: in-node fixed-window limiter foundation for org/user/token gates.

## Request Path

REST handlers return lightweight JSON envelopes and job metadata for expensive work. No Git-heavy, AI-heavy, test-heavy or merge-heavy operation is performed synchronously. Mutations are intended to pair a domain write with an evidence event and outbox event inside the same transaction as the implementation matures.
