## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/local-feature-flag-evaluator/spec.md` adds one new
      requirement (`Unrecognized property-filter operators degrade to inconclusive`) with two
      scenarios
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a one-line pointer from the "Error handling" section's existing "surfaced as
      dedicated fall-back / inconclusive signals" sentence to the new requirement

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/local-feature-flag-evaluator/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit posthog-js/posthog-node, posthog-python, posthog-ruby, and posthog-go for the
      same "unrecognized operator degrades that flag only" resilience behavior; port this
      requirement's scope to them if/when confirmed
- [ ] 4.2 Double-check posthog-php#209's `InconclusiveMatchException` catch site directly
      against the diff to confirm the per-flag (not project-wide) scoping asserted here
