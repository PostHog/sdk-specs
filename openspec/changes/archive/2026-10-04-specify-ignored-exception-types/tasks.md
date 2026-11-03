## 1. Spec delta

- [x] 1.1 Add exactly one requirement to `capture-exception`, **Ignored exception types**
- [x] 1.2 State the empty default and that the option itself is optional
- [x] 1.3 State that the list applies to every `$exception` path, before the capture pipeline
- [x] 1.4 State chain-wide, case-sensitive matching and leave the matched identifier platform-idiomatic
- [x] 1.5 Cover each of the above with a scenario

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture-exception/spec.md` and archive the change
