# Vela

The AI-native forge for trusted software.

Vela is a Git-compatible software forge built for the agent era. It combines beautiful pull requests, agent identity, deterministic merge queues, autonomous launch readiness analysis and append-only evidence so teams can trust every human and AI-generated code change.

GitHub stores code. Vela proves whether code can be trusted.

## Phase 0 Status

This repository currently implements the Phase 0 foundation:

- Phoenix LiveView control-plane app in `apps/web`
- Postgres/Ecto domain model for organizations, actors, agents, repositories, PRs, readiness scores, merge candidates, policies, runners and evidence events
- Seeded Sardis Labs demo workspace
- PR cockpit, repo overview, agent profile, launch cockpit, evidence ledger and settings surfaces
- Mock-backed Git, Merge, Maestro and Runner service contracts

The first milestone does not implement real Git hosting, real merge commits, real LLM analysis, hosted CI, production WorkOS login or enterprise compliance automation.

## Local Development

```bash
./scripts/setup.sh
./scripts/dev.sh
./scripts/check.sh
```

Open `http://localhost:4000`.

## Architecture Map

- `apps/web` is the Phoenix/Postgres control plane.
- `services/*/contracts` defines future Rust/Python service boundaries.
- `packages/protocol` holds shared event and score schema contracts.
- `docs` records product, architecture, security, evidence and roadmap decisions.

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
