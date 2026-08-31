## 1. Canonical queue lifecycle

- [x] 1.1 Sync durable retention, offline pause/resume, and identity-safe acknowledgement requirements into `openspec/specs/retry-queue/spec.md`.
- [x] 1.2 Align the logs and traces retry requirements with the durable queue lifecycle.
- [x] 1.3 Add matching private acceptance scenarios for retry exhaustion, offline recovery, and full-buffer replacement during an in-flight flush.

## 2. Validation

- [x] 2.1 Run strict OpenSpec validation for all specifications.
- [x] 2.2 Verify the final diff is limited to the retry-queue lifecycle, aligned product retry requirements, acceptance coverage, and archived OpenSpec artifacts.
