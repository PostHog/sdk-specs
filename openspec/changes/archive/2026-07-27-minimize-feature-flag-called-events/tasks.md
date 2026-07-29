## 1. Spec delta

- [x] 1.1 Add a new requirement `Minimal event mode for non-experiment flags` to
      `specs/feature-flag-called-tracker/spec.md`
- [x] 1.2 Describe both gate signals (`minimalFlagCalledEvents` remote, `minimal_flag_called_events`
      local-evaluation) and the `has_experiment` condition
- [x] 1.3 Describe the allowlisted property categories and the fail-safe-to-full-event scenarios
- [x] 1.4 Describe gate persistence across cache/definitions round-trips

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Archive the delta into `specs/feature-flag-called-tracker/spec.md`

## 3. Downstream follow-up (separate changes, not this one)

- [ ] 3.1 Re-audit the exact property allowlist once posthog-android and posthog-flutter (real
      SDK, not just the compliance adapter) ship this, to confirm the allowlist is truly
      convergent across SDKs before tightening from categories to a fixed literal list
- [ ] 3.2 Acceptance-harness scenarios for `minimalFlagCalledEvents` mock-server control, once a
      harness port picks this up
