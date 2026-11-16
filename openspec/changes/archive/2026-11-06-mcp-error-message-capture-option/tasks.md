## 1. Spec delta

- [x] 1.1 Modify the **Failure capture** requirement as a full copied-and-edited block
- [x] 1.2 Make the failure's text depend on the error message capture option, with no other effect
- [x] 1.3 Add a scenario for a thrown error with the option off

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add the error message capture row to the Configuration table

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-go: `posthogmcp.WithCaptureErrorMessages` (PostHog/posthog-go)
- [ ] 4.2 posthog-js and posthog-python: add the option
- [ ] 4.3 posthog-sdk-test-harness: step bindings for the new scenario
