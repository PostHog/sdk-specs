## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/surveys/spec.md` adds one new requirement (`Survey intro
      screen`) with five scenarios
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a one-line pointer from Behavior item 7 ("Render through a platform UI layer") to
      the new requirement, without re-describing the appearance fields there

## 3. Acceptance harness

- [x] 3.1 Add one representative scenario to `acceptance/private/surveys.feature` covering the
      intro screen's no-response/no-event advance behavior

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/surveys/spec.md`

## 5. Downstream follow-up (separate changes, not this one)

- [ ] 5.1 Audit posthog-android, posthog-ios, and posthog-flutter for intro-screen parity once
      shipped (tracked upstream in PostHog/posthog#74064); port this requirement's scope to their
      compliance notes if/when they ship it
