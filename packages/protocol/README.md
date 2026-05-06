# Vela Protocol

Shared wire contracts for evidence events, readiness scores and webhook events.

## Evidence Event Versions

Evidence exports use an explicit envelope contract:

- `schemaVersion`: semantic wire schema id. Current value: `vela.evidence.v1`.
- `envelopeVersion`: integer hash-envelope version. Current value: `1`.

`schemaVersion` changes when the public JSON shape changes. `envelopeVersion`
changes only when the canonical hash envelope changes. Consumers should reject
unknown major schema ids and unknown envelope versions until they explicitly
support them.
