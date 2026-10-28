## 1. Spec delta

- [x] 1.1 Add one `retry-queue` requirement, **Ingestion retry backoff is jittered**
- [x] 1.2 State that jitter scales the SDK's own computed delay and never replaces the schedule
- [x] 1.3 State that the jittered delay stays within the configured backoff ceiling
- [x] 1.4 State that a server `Retry-After` remains a floor applied after jitter, itself clamped to the same ceiling
- [x] 1.5 State that an SDK without usable randomness uses the unjittered delay

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any new errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/retry-queue/spec.md` and archive the change
