## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/surveys/spec.md` modifies the single `Canonical surveys
      behavior` requirement as a full copied-and-edited block
- [x] 1.2 Add the new scenario excluding web-only-conditioned surveys on non-web SDKs
- [x] 1.3 Verify the four existing scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Reword Behavior item 5 to name the selector/URL exclusion rule concretely instead of
      the vague "platform-specific display constraints" phrase

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into `specs/surveys/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 posthog-android does not exclude web-only-conditioned surveys — needs the same fix as
      posthog-ios#733. Not addressed by this spec change (documentation only).
- [ ] 4.2 posthog-flutter inherits whichever native SDK it wraps; re-check once Android ships
      4.1.
