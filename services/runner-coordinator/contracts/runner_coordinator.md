# Runner Coordinator Contract

Methods:

- `RegisterRunner(org_id, labels)`
- `Heartbeat(runner_id)`
- `LeaseJob(runner_id)`
- `AppendLogs(job_id, chunk)`
- `UploadArtifact(job_id, artifact_ref)`
- `CompleteJob(job_id, status)`
