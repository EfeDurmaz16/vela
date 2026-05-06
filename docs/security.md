# Security

Security is part of the product from day one.

Human auth is WorkOS-aligned. Agent auth uses FIDES-style identity with public keys, DID-like identifiers, trust attestations and signed events. Authorization is local and fail-closed.

Phase 0 includes schema and UI boundaries for RBAC, branch protection, agent policy, evidence events, runner metadata and WorkOS settings. The backend now includes WorkOS-backed session auth, signed provider webhook verification, webhook replay protection, idempotent mutation handling and hash-chained mutation evidence. Later phases add SCIM-depth enterprise auth flows, short-lived credentials, runner isolation, broader rate limits and audit exports.

## API Posture

Unauthenticated read API access is a named demo mode, not the production default. `config :vela, :api, demo_mode?: true` is enabled in dev and test so the seeded demo workspace remains inspectable without a browser session. Production defaults to `false`; it can only be enabled deliberately with `VELA_DEMO_MODE=true`.

When demo mode is disabled, unauthenticated read collection requests return `401 {"error":{"code":"demo_mode_required"}}`. Protected routes continue to use the WorkOS-backed Phoenix session pipeline and return `401 {"error":{"code":"api_auth_required"}}` when the session is missing, stale or tenant-mismatched.

WorkOS login and callback routes stay unauthenticated because they initiate and complete the human auth flow. Provider webhooks stay unauthenticated at the route level, but verification is handled by provider-specific signatures, timestamp replay checks and configured secret policy before trusted evidence is written.

## RBAC

Protected API routes rehydrate `current_user`, `current_organization`, `current_membership` and `current_actor` on every request. Tenant resource lookup happens before mutation. RBAC then gates mutations using the local membership role matrix:

- `owner` and `admin` have full access.
- `maintainer` can create, update, import and sync repositories, comment on PRs and queue reviewed PRs for merge, but cannot delete repositories.
- `reviewer` can create review/comment records and read evidence/readiness surfaces, but cannot queue merges.
- `observer` can read protected resources in its tenant but cannot mutate repositories, PRs or merge state.

## API Tokens

API token storage is modeled, but token issuance is not exposed yet. Token records are scoped to an organization and actor, carry explicit scopes, require expiry and have status metadata. Raw tokens must never be stored. Token hashes use HMAC-SHA256 with a Vela API-token purpose string and are verified with constant-time comparison.

Model output is always untrusted. LLM calls are not implemented in Phase 0.
