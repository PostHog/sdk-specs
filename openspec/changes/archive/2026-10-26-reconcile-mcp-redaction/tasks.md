## 1. Spec delta

- [x] 1.1 Modify **Payload privacy** as a full copied-and-edited block
- [x] 1.2 Admit `\r`, `\n`, and any trailing run of `=` in the binary check's edge windows
- [x] 1.3 Bound the PostHog token pattern by ASCII word boundaries
- [x] 1.4 State that object keys get the passes of the property's string values, and the collision rule
- [x] 1.5 Add scenarios for a key credential, a whole-word token, and line-wrapped base64
- [x] 1.6 Modify **Library identity** to name `posthog-rs-mcp` and `posthog-rs`

## 2. Applicability

- [x] 2.1 Add the `posthog-rs` row to the Applicability table

## 3. Validation

- [x] 3.1 Run `openspec validate reconcile-mcp-redaction --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change
- [x] 3.3 Run `openspec validate --specs --strict`
