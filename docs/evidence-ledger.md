# Evidence Ledger

Every important action in Vela should produce evidence.

Evidence events are append-only, actor-bound, resource-bound, timestamped, payload-hashed and hash-chained. Signatures are optional in Phase 0 and become mandatory for critical machine actors later.

The ledger enables reconstruction: who acted, what changed, what policy was evaluated, which score was computed, which merge candidate was simulated and why the final decision was made.
