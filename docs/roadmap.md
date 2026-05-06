# Roadmap

This roadmap separates visible implementation from modeled or planned work. Vela
should be evaluated by the shipped column first.

## Shipped In This Checkout

| Area | Status |
| --- | --- |
| Phoenix/Postgres control plane | LiveView app, schema, migrations, contexts and seeded Sardis Labs demo workspace. |
| Repository model | Repository CRUD, GitHub import placeholder/job flow, branch and PR sync metadata. |
| Pull request cockpit | PR overview, readiness state, reviews, checks, changed files, comment action and merge queue action. |
| Merge gates | Local approval, blocking review, branch protection, readiness and stale-base checks before queueing. |
| Evidence ledger | Hash-chained evidence writes, chain verification, API summary and UI verifier status. |
| API v1 | Demo read routes, session-backed mutating routes, RBAC, idempotency and mutation audit writes. |
| Webhook verification | GitHub, Stripe, WorkOS, Svix and generic Vela HMAC verification with replay-window checks. |
| Protocol packages | Evidence schema, webhook schema, webhook examples and readiness score schema. |
| JavaScript SDK | Minimal dependency-free client for listing repositories, queueing imports and queueing PR syncs. |
| CI/check path | Local `./scripts/check.sh` and GitHub Actions workflow for Mix and Node SDK checks. |

## In Progress Or Partial

| Area | Current boundary |
| --- | --- |
| GitHub sync depth | Repository, branch, PR, changed-file, review and check-run metadata are modeled. Full mirror fidelity is still future work. |
| Merge queue | Local queue state and gates exist. Provider-side merge execution and signed merge commits are not implemented. |
| Maestro analysis | Deterministic Phoenix-local analyzers and signed callbacks exist. The Python analysis sidecar is still contract-only. |
| Provider webhooks | Incoming verification and integration event persistence exist. Outbound webhook delivery/retry is not yet implemented. |
| WorkOS auth | Server-side login/callback/session reconciliation exists. Enterprise provisioning depth such as SCIM remains planned. |
| Agent-native controls | Actors, agent sessions, signatures and policy models exist. Branch leases, short-lived tokens and conflict arbitration remain planned. |

## Planned Next

| Priority | Work |
| --- | --- |
| P0 | Real outbound webhook delivery worker with retries, dead-letter handling and delivery evidence. |
| P0 | Provider merge adapter boundary for GitHub merge execution behind the existing local gates. |
| P0 | Production auth posture hardening for non-demo read routes and tenant-scoped API tokens. |
| P1 | External Maestro service implementation for tests, security, performance and API contract analyzers. |
| P1 | Rich diff viewer and behavior/risk summaries backed by imported changed-file data. |
| P1 | Audit exports and enterprise evidence package generation. |
| P2 | Git gateway/repo-engine sidecars for real forge hosting semantics. |
| P2 | Agent branch leases, delegated credentials, signed tool timelines and multi-agent conflict detection. |

## Not Phase 0

- Full Git hosting replacement.
- Hosted CI runner product.
- Compliance automation platform.
- Production-grade SCIM/data-residency suite.
- Autonomous merge execution without explicit local gates and evidence.
