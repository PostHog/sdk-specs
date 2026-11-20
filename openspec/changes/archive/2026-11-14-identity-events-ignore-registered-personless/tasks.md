## 1. Spec delta

- [x] 1.1 Add **Identity events ignore a registered personless setting** to `capture` with four scenarios

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Run `openspec archive` to sync the delta and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 Reconcile the client sentence in PR #146's **Distinct ids and identity fallbacks on capture v1** with this requirement when that PR merges
- [ ] 3.2 Audit posthog-js browser against the rule
- [ ] 3.3 Audit posthog-kmp on its non-Android, non-Apple targets, and posthog-unity and posthog-godot
- [ ] 3.4 posthog-sdk-test-harness: step bindings for registered event options, then add the scenarios to `acceptance/public/capture.feature`
