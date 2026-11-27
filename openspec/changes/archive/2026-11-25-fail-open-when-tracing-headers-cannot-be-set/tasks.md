## 1. Spec delta

- [x] 1.1 Add the "Client injection fails open and keeps the request intact" requirement to `tracing-headers`

## 2. Validation

- [x] 2.1 Run `openspec validate fail-open-when-tracing-headers-cannot-be-set --strict`
- [x] 2.2 Archive the change, syncing the delta into `specs/tracing-headers/spec.md`
- [x] 2.3 Run `openspec validate --specs --strict`
