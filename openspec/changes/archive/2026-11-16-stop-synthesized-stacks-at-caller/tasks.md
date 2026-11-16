## 1. Spec delta

- [x] 1.1 Add **Synthesized stacks stop at the application call site** to `capture-exception` with two scenarios

## 2. Validation

- [x] 2.1 Sync the delta into `openspec/specs/capture-exception/spec.md` and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-ios: land the 4.0 port, PostHog/posthog-ios#1080
- [ ] 3.2 Audit the remaining SDKs that synthesize a current stack (android, flutter, react-native, kmp, unity, dotnet, java, go, php, ruby, elixir, rs)
- [ ] 3.3 posthog-sdk-test-harness: step bindings for the new scenarios
