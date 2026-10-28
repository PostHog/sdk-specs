## 1. Spec delta

- [x] 1.1 Modify the **Person identity** requirement as a full copied-and-edited block
- [x] 1.2 Replace the optional `$identify` with a prohibition
- [x] 1.3 Add a scenario that an identified call sends no `$identify`

## 2. Acceptance coverage

- [x] 2.1 Assert no `$identify` in the identified-call scenario of the public MCP Analytics feature

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change
