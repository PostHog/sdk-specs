## 1. Spec delta

- [x] 1.1 Add the **Ordered hand-over while a before-send hook can complete asynchronously** requirement to `before-send-hook`
- [x] 1.2 Narrow the **Concurrency & ordering guarantees** prose so synchronous execution describes the SDKs it is true of

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/before-send-hook/spec.md` and archive the change
