## 1. Spec delta

- [x] 1.1 Modify **Failure capture**: the derivation rule for `$mcp_error_status` and one scenario

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Property reference: `$mcp_error_status` is an integer from 100 to 599

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-python and posthog-js derive it
- [ ] 4.2 posthog-go, posthog-ruby and posthog-rs derive it
- [ ] 4.3 posthog-sdk-test-harness: a step binding for the new scenario, then add it to
  `acceptance/public/mcp-analytics.feature`
