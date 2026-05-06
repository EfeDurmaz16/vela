# Vela

[![CI](https://github.com/EfeDurmaz16/vela/actions/workflows/ci.yml/badge.svg)](https://github.com/EfeDurmaz16/vela/actions/workflows/ci.yml)

Trusted forge control plane for human and agent-generated software changes.

Vela sits next to Git hosting and makes code-change trust explicit before a
change is merged, shipped, or delegated to an agent. It models repositories,
pull requests, actors, agent sessions, readiness signals, merge candidates,
policy decisions, and append-only evidence in one Phoenix/Postgres control
plane.

GitHub stores code. Vela records why a change was trusted, blocked, queued, or
cancelled.

## What Vela Does

- Imports GitHub repository and pull request metadata into a local forge model.
- Tracks human and agent actors separately so authority is visible in workflow
  state.
- Computes readiness inputs from deterministic analyzers, synced PR metadata,
  reviews, checks, and changed files.
- Gates merge queue entry before local merge candidates can move to `queued`.
- Writes hash-chained evidence and pending outbox events for accepted
  mutations.
- Exposes a small v1 API, protocol schemas, webhook examples, and a minimal
  JavaScript SDK for integration work.

## Phase 0 Status

This repository currently implements the Phase 0 foundation, not a complete
hosted forge:

- Phoenix LiveView control-plane app in `apps/web`
- Postgres/Ecto domain model for organizations, actors, agents, repositories,
  PRs, readiness scores, merge candidates, policies, runners and evidence events
- Seeded Sardis Labs demo workspace
- Repository overview, PR cockpit, changed-file view, merge queue actions,
  evidence ledger, chain verifier status, agent profile, launch cockpit and
  settings surfaces
- Session-backed API auth, RBAC checks, idempotent job mutations, signed
  analysis callbacks and provider webhook verification
- Mock-backed Git, Merge, Maestro and Runner service contracts for future
  sidecars

The first milestone does not implement real Git hosting, real merge commits,
hosted CI execution, production WorkOS tenant provisioning or enterprise
compliance automation.

## Status Matrix

| Area | Current state | Notes |
| --- | --- | --- |
| Phoenix control plane | Implemented | LiveView app, API routes, seeded demo workspace and Postgres domain model. |
| GitHub repository import | Implemented for metadata | Imports repository, branch and PR metadata through queued jobs; not a Git remote. |
| Pull request cockpit | Implemented | Shows PR state, readiness, reviews, checks, changed files and local actions. |
| Merge queue | Implemented locally | Queues local merge candidates after gates pass; does not create real merge commits yet. |
| Evidence ledger | Implemented | Appends hash-chained events, verifies repository/org chains and exposes API/UI summaries. |
| Provider webhooks | Partial | Verifies provider signatures and ingests integration events; delivery/retry workers are still pending. |
| Analysis/Maestro | Partial | Deterministic local analyzers and signed callback path exist; external analysis service is still a contract boundary. |
| SDK/protocol packages | Early but real | JSON schemas, webhook examples and dependency-free JS client cover the Phase 0 path. |
| Hosted forge/CI/compliance | Not implemented | Future sidecar and deployment work; do not treat this repo as a production GitHub replacement. |

## Local Development

Prerequisites:

- Elixir/OTP compatible with `apps/web/mix.exs`
- Postgres
- Node.js 22+ for SDK tests

```bash
./scripts/setup.sh
./scripts/dev.sh
./scripts/check.sh
```

Open `http://localhost:4000`.

Run the same check used by CI:

```bash
./scripts/check.sh
```

## Architecture Map

- `apps/web` is the Phoenix/Postgres control plane.
- `services/*/contracts` defines future Rust/Python service boundaries.
- `packages/protocol` holds shared event and score schema contracts.
- `packages/sdk-js` holds the dependency-free Phase 0 JavaScript API client.
- `docs` records product, architecture, security, evidence and roadmap decisions.

## Integration Surface

- API reference: [docs/api.md](docs/api.md)
- Protocol schemas: [packages/protocol](packages/protocol)
- JavaScript SDK: [packages/sdk-js](packages/sdk-js)
- Webhook examples: [packages/protocol/examples/webhooks](packages/protocol/examples/webhooks)
- Status audit: `./scripts/status-audit.sh`

## Docs

- [Vision](docs/vision.md)
- [Architecture](docs/architecture.md)
- [Product](docs/product.md)
- [UI/UX](docs/ui-ux.md)
- [Security](docs/security.md)
- [Agent model](docs/agent-model.md)
- [Merge queue](docs/merge-queue.md)
- [Maestro](docs/maestro.md)
- [Evidence ledger](docs/evidence-ledger.md)
- [API](docs/api.md)
- [Deployment](docs/deployment.md)
- [Roadmap](docs/roadmap.md)
- [Transformation summary](docs/transformation-summary.md)
- [Contributing](CONTRIBUTING.md)
