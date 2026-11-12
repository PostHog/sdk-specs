## 1. Spec delta

- [x] 1.1 Modify **Session identity**: `$mcp_session_source` and its four values, and the property in
  two existing scenarios
- [x] 1.2 Add the property to the matching scenarios in `acceptance/public/mcp-analytics.feature`

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add `$mcp_session_source` to Property reference

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-go, posthog-ruby and posthog-rs, with their client conversation id rows
- [ ] 4.2 posthog-sdk-test-harness: step bindings for the new assertions
- [ ] 4.3 The manual APIs: return the source from the call step and accept it on capture
