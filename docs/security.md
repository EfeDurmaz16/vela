# Security

Security is part of the product from day one.

Human auth is WorkOS-aligned. Agent auth uses FIDES-style identity with public keys, DID-like identifiers, trust attestations and signed events. Authorization is local and fail-closed.

Phase 0 includes schema and UI boundaries for RBAC, branch protection, agent policy, evidence events, runner metadata and WorkOS settings. The backend now includes WorkOS-backed session auth, signed provider webhook verification, webhook replay protection, idempotent mutation handling and hash-chained mutation evidence. Later phases add SCIM-depth enterprise auth flows, short-lived credentials, runner isolation, broader rate limits and audit exports.

Model output is always untrusted. LLM calls are not implemented in Phase 0.
