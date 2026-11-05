## 1. Spec delta

- [x] 1.1 Modify the **Failure capture** requirement as a full copied-and-edited block
- [x] 1.2 Add the classifier, `$mcp_error_expected`, and `not_found` to it
- [x] 1.3 Modify the **Manual capture** requirement so the result step and the lower-level method take
  the expected flag
- [x] 1.4 Add scenarios for a classified `isError` result and a manual expected failure

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add the error classifier row to the Configuration table
- [x] 2.2 Add `$mcp_error_expected` to the Property reference
- [x] 2.3 Add both scenarios to `acceptance/public/mcp-analytics.feature`

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-sdk-test-harness: step bindings for the new scenarios
- [ ] 4.2 Implement the option and the manual field in every SDK that implements MCP analytics
