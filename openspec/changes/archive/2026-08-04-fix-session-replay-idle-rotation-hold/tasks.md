## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/session-replay-ingestion-controls/spec.md` adds one new
      requirement (`Interaction hold for unconfirmed-activity recording epochs`) with three
      scenarios
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a clarifying sentence to the "Session rotation" lifecycle bullet noting that both
      an idle-timeout rotation and a fresh session start are held until confirmed activity,
      an independent trigger, or an explicit recording override

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/session-replay-ingestion-controls/spec.md`

## 3a. Correction before merge (same monitoring pass)

- [x] 3a.1 posthog-js#4412 shipped days after #4407 and extended the hold to fresh
      (non-rotation) session starts, directly contradicting this change's original "a fresh
      session start is not held" requirement text and scenario while still in draft. Broadened
      the requirement, renamed it, and replaced the contradicted scenario with two scenarios
      (fresh-start hold; unload-behavior split between fresh-start and rotation-born holds)
      before this change merged, so the canonical spec never asserts the now-false claim.
- [x] 3a.2 posthog-js#4410 (V2 event-trigger release parity) checked against the requirement's
      release conditions — already covered generically by "an event/URL trigger independently
      activates recording," no further spec change needed for it.

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Check whether `posthog-ios` / `posthog-android` start or rotate sessions without a
      confirmed-interaction signal the same way as web, and if so whether they have (or need) an
      equivalent hold; if they don't, the requirement's scoping clause already exempts them and
      no further action is needed
- [ ] 4.2 The RECORDING_MAX_EVENT_SIZE-triggered drop-and-resnapshot behavior for held buffers
      (posthog-js#4412) was deliberately left out of the requirement text as an implementation
      detail below this spec's abstraction level — revisit if it turns out to be an
      observable/cross-SDK contract point worth stating explicitly
