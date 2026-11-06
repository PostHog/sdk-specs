## 1. Spec delta

- [x] 1.1 Remove the payload personal data pass from **Payload privacy** and state that tool payloads are relayed as captured after the credential passes
- [x] 1.2 Remove the `payload personal data` Configuration row
- [x] 1.3 Remove the payload scenarios from `acceptance/public/mcp-analytics.feature`, and add the relayed-as-captured scenario to the spec
- [x] 1.4 Keep the `$mcp_feedback_<name>` JSON text rule and the "Optional events" wording from the previous change

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` with openspec 1.4.1
- [x] 2.2 Sync the delta into `specs/mcp-analytics/spec.md` and archive the change
