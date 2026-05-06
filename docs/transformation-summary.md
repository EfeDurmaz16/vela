# Transformation Summary

This repo has moved from a Phase 0 demo narrative toward a more reviewable
trusted forge control plane. The important change is not cosmetic volume; it is
that claims are now closer to code, tests, protocol contracts and verification
commands.

## What Changed

- API behavior is split into focused v1 modules instead of one growing
  controller surface.
- Auth, RBAC, demo-mode read posture, idempotent job mutations and mutation
  audit writes are documented and tested.
- GitHub repository and PR metadata workflows now have real import/sync job
  paths, evidence writes and outbox records.
- Merge queue actions are backed by local gates for approvals, blocking
  reviews, branch protection, readiness and stale base state.
- Evidence chains have versioned export envelopes, verifier status in the UI,
  API verification summaries and protocol schema coverage.
- Webhook event payloads have versioned schema examples validated by Mix tests.
- The JavaScript SDK has a minimal but real client path for repository listing,
  import queueing and PR sync queueing.
- Public repo surfaces now include README status, roadmap taxonomy, contribution
  guidance, issue templates, PR template, CI workflow and status audit script.

## Current Honest Position

Vela is now best described as:

> A Phoenix/Postgres trusted forge control plane that imports GitHub metadata,
> gates local merge queue state, records hash-chained evidence, and exposes a
> small integration surface for Phase 0 workflows.

It is not yet:

- a full Git hosting replacement
- a hosted CI system
- a production WorkOS/SCIM enterprise suite
- a provider-side merge executor
- an autonomous agent execution platform

## Verification

Primary verification command:

```sh
./scripts/check.sh
```

Status audit command:

```sh
./scripts/status-audit.sh
```

These cover the practical baseline: formatting, compile with warnings as
errors, full Mix tests, controller-size guard, Node SDK tests and public repo
surface audit.

## Next Highest-Leverage Work

1. Implement outbound webhook delivery with retries, dead-letter handling and
   delivery evidence.
2. Add the provider merge execution adapter behind the existing local gates.
3. Expose tenant-scoped API token issuance for scripted clients.
4. Move Maestro from contract/deterministic-local analysis into a real external
   analysis worker.
5. Add richer changed-file/diff inspection backed by imported provider metadata.
