## 1. Establish the contract

- [x] 1.1 Verify the replay ingestion metadata extraction, concatenation, and publication paths against pinned backend source.
- [x] 1.2 Document the session/identity request boundary and implementation gaps.
- [x] 1.3 Add scenarios for session changes, identity-only changes, restored snapshots, retries, and compatible snapshots.

## 2. Validate and synchronize

- [x] 2.1 Validate the delta with `openspec validate define-replay-batch-attribution --strict --no-interactive`.
- [x] 2.2 Apply and archive the delta into the canonical event-batcher spec, then validate all specs strictly.
