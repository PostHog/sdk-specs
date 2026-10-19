## 1. Spec delta

- [x] 1.1 Add one `event-batcher` requirement, **Analytics requests are bounded by serialized size**
- [x] 1.2 State that the byte bound applies in addition to the event-count limit
- [x] 1.3 State that splitting preserves order and discards nothing
- [x] 1.4 State that an event larger than the target is sent alone, with no per-event cap on the analytics lane
- [x] 1.5 Keep the existing `413` shrink path as the reactive backstop

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any new errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/event-batcher/spec.md` and archive the change
