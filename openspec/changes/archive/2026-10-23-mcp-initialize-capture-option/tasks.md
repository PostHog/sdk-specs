## 1. Spec delta

- [x] 1.1 Modify the **Optional events** requirement as a full copied-and-edited block
- [x] 1.2 Make `$mcp_initialize` depend on the initialize capture option, with no other effect
- [x] 1.3 Add the `@mcp_initialize_capable` tag and two scenarios

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add the initialize capture row to the Configuration table

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-sdk-test-harness: step bindings for the two `@mcp_initialize_capable` scenarios, and
  the scenarios in `acceptance/public/mcp-analytics.feature`
