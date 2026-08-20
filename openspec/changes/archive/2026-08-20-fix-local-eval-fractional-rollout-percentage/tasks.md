## 1. Spec addition

- [x] 1.1 Add a "Fractional rollout percentages" requirement to
      `specs/local-feature-flag-evaluator/spec.md` stating `rollout_percentage` SHALL be treated
      as a floating-point number and MUST NOT be truncated/rounded before bucketing
- [x] 1.2 Add a scenario for a fractional rollout (e.g. 0.1%) matching correctly
- [x] 1.3 Add a scenario for boundary values (100.0 / 0.0 / unset) continuing to behave correctly
      after widening the type

## 2. Validation

- [ ] 2.1 Run `openspec validate --specs --strict` and resolve any errors (CLI unavailable in the
      authoring sandbox; CI on the PR should run this)

## 3. Downstream follow-up (separate work, not this change)

- [ ] 3.1 Check whether posthog-python, posthog-node, posthog-php, posthog-ruby, and posthog-go's
      local evaluators already treat `rollout_percentage` as a float, or share the same
      truncation bug android/dotnet had
