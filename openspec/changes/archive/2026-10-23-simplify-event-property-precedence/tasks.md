## 1. Spec delta

- [x] 1.1 Modify **Caller-supplied event properties take precedence** in `capture` to the three-layer order, replacing the person-processing scenario
- [x] 1.2 Rewrite Behavior step 4 in `capture` to match
- [x] 1.3 Update the matching scenario in `acceptance/public/capture.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture/spec.md` and archive the change
