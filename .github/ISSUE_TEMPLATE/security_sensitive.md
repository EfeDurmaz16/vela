---
name: Security-sensitive engineering issue
about: Track auth, webhook, evidence, merge gate, idempotency, or secret-handling work
title: "security: "
labels: security
assignees: ""
---

## Boundary

- [ ] API auth / tenant checks
- [ ] RBAC
- [ ] Webhook verification
- [ ] Evidence integrity
- [ ] Merge gates
- [ ] Idempotency
- [ ] Secret handling
- [ ] Agent signatures / policy

## Risk

What could an attacker, confused user, compromised integration, or autonomous
agent do if this boundary is wrong?

## Current Behavior

Describe the existing implementation or gap.

## Desired Behavior

Describe the fail-closed behavior, audit trail, or verification requirement.

## Validation

List the tests, negative cases, and manual checks required before closing.

## Sensitive Data

Do not paste secrets, tokens, private keys, webhook secrets, raw credentials, or
sensitive payment data into this issue.
