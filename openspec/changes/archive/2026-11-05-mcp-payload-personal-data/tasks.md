## 1. Spec delta

- [x] 1.1 Extend **Payload privacy** so the personal data pass covers payload strings and keys, card-number numbers, `$mcp_error_message`, resource read URIs, and `$exception` values and source lines
- [x] 1.2 Order the pass before the URL pass, and count names it changes as unrecorded in `$mcp_input_keys`
- [x] 1.3 Add the payload personal data option to the Configuration table
- [x] 1.4 Mark `$mcp_feedback_<name>` JSON text sanitized, and fix the stale reason in **Optional events**
- [x] 1.5 Add scenarios to the spec and to `acceptance/public/mcp-analytics.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --strict`
- [x] 2.2 Sync the delta into `specs/mcp-analytics/spec.md` and archive the change
