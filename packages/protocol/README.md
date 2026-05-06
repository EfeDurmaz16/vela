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

## Webhook Event Versions

Webhook deliveries use `schemaVersion: "vela.webhook.v1"` with a stable event
envelope:

- `id`: Vela event delivery id.
- `type`: domain event name, for example `merge.queued`.
- `created_at`: ISO-8601 event creation timestamp.
- `data`: event-specific payload.

Current examples live in `examples/webhooks/` and cover:

- `repo.import_queued`
- `pr.comment.created`
- `merge.queued`
- `merge.cancelled`

Consumers should route by `type` after checking `schemaVersion`. New event types
can be added under the same schema version when the envelope stays compatible.
