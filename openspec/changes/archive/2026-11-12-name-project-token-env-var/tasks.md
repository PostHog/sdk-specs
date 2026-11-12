## 1. Spec delta

- [x] 1.1 Add **Project token environment variable name** to `setup`, with scenarios for the new
  variable, the deprecated fallback, and precedence

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Archive the change and sync the delta into `openspec/specs/setup/spec.md`

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-rs, posthog-ruby and `@posthog/ai` read `POSTHOG_PROJECT_TOKEN` first
- [ ] 3.2 posthog-sdk-test-harness: step bindings for the environment-variable scenarios
