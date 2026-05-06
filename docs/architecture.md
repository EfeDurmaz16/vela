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
- `Vela.Jobs`: facade for expensive import, sync, analysis, scoring and simulation jobs.
- `Vela.Jobs.RepositoryJobs`, `Vela.Jobs.AnalysisJobs`, `Vela.Jobs.ScoringJobs`, `Vela.Jobs.MergeJobs`: domain-specific Oban constructor registries.
- `Vela.Integrations`: adapter behavior and persisted provider/service/environment records.
- `Vela.Forge.Repositories`, `Vela.Forge.PullRequests`, `Vela.Forge.Reviews`, `Vela.Forge.TrustSignals`: focused forge-domain read/write surfaces behind the `Vela.Forge` facade.
- `Vela.Merge.Gates`: review and readiness gates that must pass before a merge candidate can be queued.
- `Vela.Maestro.ScoringProfiles`: weighted launch readiness profile definitions and score calculation.
- `Vela.Webhooks.Verifiers.*`: provider-specific signature verifiers for GitHub, Stripe, WorkOS, Svix and generic Vela HMAC fallback.
- `Vela.Git.*`: behaviours for GitProvider, RepoImporter, RefService, DiffService and MergeSimulator sidecars.
- `Vela.Storage.ObjectStore`: object storage boundary for logs, artifacts, analysis outputs and releases.
- `Vela.Auth.WorkOS`: WorkOS SSO boundary for human auth.
- `Vela.Agents.SignatureVerifier`: signed agent identity verification boundary.
- `Vela.Crypto`: AES-GCM token encryption helper for integration secrets.
- `Vela.RateLimit`: in-node fixed-window limiter foundation for org/user/token gates.
- `Vela.Git.GitHubClient`: GitHub REST import/ref/compare/comment adapter using `Req`.
- `Vela.Storage.S3ObjectStore`: S3-compatible object store with AWS SigV4 signed PUT and presigned GET support.

## Runtime Configuration

- `WORKOS_API_KEY`, `WORKOS_CLIENT_ID`, `WORKOS_REDIRECT_URI`
- `GITHUB_TOKEN`
- `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`
- `VELA_WEBHOOK_SECRET` for a shared webhook signing secret, or `VELA_<PROVIDER>_WEBHOOK_SECRET` / `<PROVIDER>_WEBHOOK_SECRET` for provider-specific secrets.
- `VELA_ALLOW_UNSIGNED_WEBHOOKS=1` can temporarily relax production webhook signature enforcement.
- `VELA_WEBHOOK_TOLERANCE_SECONDS` controls the replay window for timestamped webhook signatures. The default is 300 seconds.

## Credential Smoke Checks

Run `mix vela.smoke` from `apps/web` to check configured provider credentials without mutating remote state.

- WorkOS verifies `WORKOS_API_KEY` only when `WORKOS_SMOKE_SESSION_ID` is also set.
- GitHub verifies `GITHUB_TOKEN` only when `GITHUB_SMOKE_OWNER` and `GITHUB_SMOKE_REPO` identify a repository the token can read.
- S3-compatible storage performs a read-only signed GET only when `S3_SMOKE_KEY` points at an existing object. It does not PUT smoke objects because the current object-store adapter has no delete operation.
- Webhook signing verifies the configured local HMAC secret from `VELA_WEBHOOK_SECRET` or provider-specific webhook secret env vars.

Missing smoke-specific configuration is reported as `SKIP`. Configured checks that fail are reported as `FAIL` and make the Mix task exit nonzero. Use `mix vela.smoke --check github` or `mix vela.smoke --checks workos,github` to limit the run.

## Request Path

REST handlers return lightweight JSON envelopes and job metadata for expensive work. No Git-heavy, AI-heavy, test-heavy or merge-heavy operation is performed synchronously. Mutating job endpoints pair the queued Oban job with a hash-chained evidence event and a pending outbox event inside the same database transaction.
