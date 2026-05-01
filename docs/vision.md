# Vision

Vela exists because AI-generated code changes the scale and shape of software review.

Traditional forges optimize for storing code, listing diffs and coordinating human review. That is not enough when agents generate large diffs, run tools, create tests, update branches, interact with CI and touch security-sensitive paths. CI passing says a command succeeded. It does not explain behavioral impact, actor provenance, policy scope, rollback safety or whether the tested tree is the tree that lands.

Vela's wedge is the PR cockpit plus launch readiness proof. The reviewer should understand what changed, why it changed, who or what changed it, what evidence supports it, what risk remains and whether it can merge safely before reading the raw diff.

Target users are founders, infrastructure teams, security-sensitive engineering orgs and AI-heavy product teams that need to trust human and agent-created code without pretending manual review scales forever.

The product principle is simple: diff second, decision first.
