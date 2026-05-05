# Agent Model

Vela treats humans, agents, systems, integrations, runners, scanners and deployment bots as first-class actors.

Human authentication is WorkOS-aligned. Agent identity follows a FIDES-style model: DID-like identifiers, public keys, trust scores, issuer organizations, signing key references and policy scopes.

Agent sessions record task intent, prompt hash, model, toolchain, branch, human supervisor, status and timestamps. Agent policies restrict repositories, branches, paths, forbidden paths, PR size, merge rights and deployment rights.

Phase 0 stores the model, renders provenance and verifies Ed25519 agent signatures at the backend boundary. Later phases add token issuance, branch lease enforcement, signed event requirements for critical machine actors and multi-agent conflict detection.
