# Contributing to Vela

Vela is a trusted forge control plane. Contributions should improve real
engineering credibility: safer merge decisions, clearer evidence, tighter API
contracts, better developer workflows, and honest documentation.

## Current Stack

- `apps/web`: Phoenix, LiveView, Ecto, Postgres, Oban.
- `packages/protocol`: JSON schema contracts for public wire shapes.
- `packages/sdk-js`: dependency-free JavaScript client for the Phase 0 API.
- `services/*`: sidecar contract documents and future service boundaries.
- `docs`: architecture, product, security, API, evidence, and roadmap notes.

Use the existing language and package manager in the area you touch. Avoid new
dependencies unless they remove real complexity or provide protocol/security
correctness that local code should not reimplement.

## Local Verification

Run the full repo check before opening a PR:

```sh
./scripts/check.sh
```

This currently runs:

- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix test`
- a controller-size guard for the v1 API facade
- `node --test packages/sdk-js/test/*.test.mjs`

For focused work, use the narrowest useful check first, then the full script
before marking the branch ready.

## Commit Shape

Keep commits atomic and reviewable:

- `feat(protocol): add webhook payload examples`
- `test(merge): cover stale base gate`
- `docs(api): document idempotency behavior`
- `fix(sdk-js): align PR sync route`

Do not mix unrelated docs, schema, UI, and test changes in one commit unless the
change cannot be reviewed coherently without them.

## Security-Sensitive Areas

Treat these areas as security-sensitive:

- API auth and tenant checks.
- Webhook signature verification and replay windows.
- Merge queue gates and state transitions.
- Evidence hashes, signatures, exports, and verification.
- Job idempotency and mutation audit writes.
- Any future signing, wallet, payment, or policy execution path.

Default to deny-by-default behavior, preserve audit trails, and avoid logging
tokens, private keys, webhook secrets, or raw credentials.

## Good First Contributions

High-signal contributions include:

- Tests for missing gate, auth, idempotency, or evidence edge cases.
- Small API docs improvements backed by existing route behavior.
- Protocol examples that are validated by tests.
- SDK serialization tests for existing endpoints.
- UI states that expose real domain state instead of placeholder copy.
- Bug reports with reproduction steps and expected/actual behavior.

Avoid shallow churn such as cosmetic renames, broad formatting-only diffs, or
new dependencies that are not tied to a concrete integration need.

## PR Checklist

Before requesting review:

- Explain the behavioral change and the affected surface.
- Link the issue or plan item if one exists.
- Include the exact verification command output summary.
- Call out any skipped checks and why they were skipped.
- Note security, tenant-boundary, or migration implications.
