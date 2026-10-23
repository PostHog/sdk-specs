## 1. Spec delta

- [x] 1.1 Modify the **Optional events** requirement as a full copied-and-edited block
- [x] 1.2 Make `$mcp_tools_list` depend on the tools list capture option, with no other effect
- [x] 1.3 Add a scenario under `@mcp_tools_list_capable`

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add the tools list capture row to the Configuration table

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-sdk-test-harness: step bindings for the new scenario
