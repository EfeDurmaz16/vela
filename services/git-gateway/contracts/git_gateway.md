# Git Gateway Contract

Methods:

- `AuthenticatePush(actor, repo, credential)`
- `ReceivePack(repo, actor, packfile_ref)`
- `UploadPack(repo, actor, wants, haves)`
- `ResolveRepository(org_slug, repo_slug)`
- `ValidateRefUpdate(repo, ref, old_sha, new_sha)`
- `EmitPushReceived(repo, actor, ref, head_sha)`

Phase 0 has no real Git protocol implementation.
