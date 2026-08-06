## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/capture-exception/spec.md` adds one new requirement
      (`Stack trace preservation over synthesis`) with one scenario
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a preservation clause to Behavior item 3 ("Normalize the input into PostHog
      exception properties")

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/capture-exception/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit native iOS/Android/Flutter/Unity error coercers for the same
      stack-discarding-in-favor-of-synthesis defect class, independent of `@posthog/core`
