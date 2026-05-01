# Agent Model

Vela treats humans, agents, systems, integrations, runners, scanners and deployment bots as first-class actors.

Human authentication is WorkOS-aligned. Agent identity follows a FIDES-style model: DID-like identifiers, public keys, trust scores, issuer organizations, signing key references and policy scopes.

Agent sessions record task intent, prompt hash, model, toolchain, branch, human supervisor, status and timestamps. Agent policies restrict repositories, branches, paths, forbidden paths, PR size, merge rights and deployment rights.

Phase 0 stores the model and renders provenance. Later phases add token issuance, signature verification, branch lease enforcement and multi-agent conflict detection.
