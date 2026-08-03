## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/retry-queue/spec.md` modifies the single
      `Canonical retry-queue behavior` requirement as a full copied-and-edited block
- [x] 1.2 Add the new scenario for flush-time removal-by-identity correctness
- [x] 1.3 Verify the three existing scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a removal-by-identity clause to Behavior item 6 ("Preserve queued events for
      retry")
- [x] 2.2 Add a sentence to "Concurrency & ordering guarantees" stating that events captured
      during an in-flight flush must survive it

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/retry-queue/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit `posthog-python`, native `posthog-ios`/`posthog-android`, and `posthog-flutter`
      retry-queue implementations for the same positional-removal-after-flush defect class,
      independent of the shared JS/TS stateless queue
