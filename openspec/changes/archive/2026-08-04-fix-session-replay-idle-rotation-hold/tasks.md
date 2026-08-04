## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/session-replay-ingestion-controls/spec.md` adds one new
      requirement (`Idle-rotation replay hold until interaction`) with two scenarios
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a clarifying sentence to the "Session rotation" lifecycle bullet distinguishing
      an idle-timeout rotation (held) from a fresh session start (not held)

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/session-replay-ingestion-controls/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Check whether `posthog-ios` / `posthog-android` rotate sessions on a foreground
      inactivity timeout the same way as web, and if so whether they have (or need) an
      equivalent hold; if they don't rotate that way, the requirement's scoping clause already
      exempts them and no further action is needed
