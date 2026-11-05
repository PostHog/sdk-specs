## 1. Spec delta

- [x] 1.1 Add the **Event schema stability** requirement to `mcp-analytics`
- [x] 1.2 Add an untagged scenario to **Tool call event**: a call to an unregistered tool sends no `$mcp_tool_call`
- [x] 1.3 Make `llm_model` optional in **Arguments the SDK injects**
- [x] 1.4 Add the matching untagged scenario to `acceptance/public/mcp-analytics.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/mcp-analytics/spec.md` and archive the change
