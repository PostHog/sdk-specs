## 1. Spec delta

- [x] 1.1 Rename "The queue-depth key stays on every non-`$snapshot` event" to "The queue-depth key is attached only while the send queue is backed up" and rewrite it: SHALL NOT attach at depth `0`, browser SHALL attach above `0`, mobile SHOULD attach at or above `flushAt`
- [x] 1.2 Update the scenarios in "Session, queue, hold-reason, trigger, and mode keys", "Attach the disabled shape when replay is not configured", and "Attach only the disabled shape while replay is intentionally off" that expected the queue key on every event

## 2. Validation

- [x] 2.1 Run `openspec validate attach-queue-depth-only-when-degraded --strict`
- [x] 2.2 Archive the change, syncing the delta into `specs/session-replay-debug-properties/spec.md`, and edit the Purpose sentence about the queue-depth key
- [x] 2.3 Run `openspec validate --specs --strict`
