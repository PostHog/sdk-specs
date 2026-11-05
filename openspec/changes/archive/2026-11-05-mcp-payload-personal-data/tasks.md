## 1. Spec delta

- [x] 1.1 Extend **Payload privacy** so the personal data pass covers `$mcp_parameters`, `$mcp_response`, `$mcp_error_message` and `$exception` values, keeping keys, numbers and booleans
- [x] 1.2 Add the payload personal data option to the Configuration table
- [x] 1.3 Add scenarios for default redaction in payloads and errors, and for the opt-out
- [x] 1.4 Add the matching scenarios to `acceptance/public/mcp-analytics.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --strict` on the change
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/mcp-analytics/spec.md` and archive the change
