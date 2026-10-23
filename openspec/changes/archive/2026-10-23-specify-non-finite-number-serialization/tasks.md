## 1. Spec delta

- [x] 1.1 Add the **Capture normalizes non-finite numeric property values** requirement to `capture`, covering wire and disk serialization, nested objects and arrays, `before_send`, and caller-container preservation
- [x] 1.2 Record the unresolved object-member placement divergence inside the requirement rather than picking a winner
- [ ] 1.3 Acceptance coverage — deferred; the JSON-document capture steps cannot express a non-finite value

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors on the touched spec
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture/spec.md` and archive the change
