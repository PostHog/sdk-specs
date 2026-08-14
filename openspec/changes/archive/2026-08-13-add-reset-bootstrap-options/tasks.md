## 1. Spec delta

- [x] 1.1 Add new requirement to `specs/reset/spec.md`: `Reset MAY accept bootstrap options to
      seed the next identity`, with two scenarios
- [x] 1.2 Verify existing requirements and scenarios are unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Update `specs/reset/spec.md` "Surface variants" to add the browser
      `options?: boolean | ResetOptions` form alongside the legacy boolean form
- [x] 2.2 Update `specs/bootstrap/spec.md` Purpose statement to qualify "dropped on `reset()`"

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Confirm whether posthog-node / posthog-react-native / other client SDKs pick up the same
      reset-bootstrap-options extension later; this change only documents the confirmed
      browser-only surface
- [ ] 4.2 Consider whether cookieless-mode interaction, session-ID clock-skew validation, and
      "plain reset restores init-time bootstrap metadata" deserve their own scenarios
