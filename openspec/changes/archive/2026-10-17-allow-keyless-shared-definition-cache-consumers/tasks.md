## 1. Spec delta

- [x] 1.1 Modify exactly one requirement in `flag-definition-loader`, **External flag definition cache providers**, as a full copied-and-edited block
- [x] 1.2 State that a configured provider is an alternative to privileged auth, and that local evaluation is not refused solely for a missing key
- [x] 1.3 Scope the decision-first provider step to refreshes with privileged local-evaluation auth configured
- [x] 1.4 State the keyless consumer path: read the cache directly, no fetch-decision call, no store call, no direct definition API request, and no auth/HTTP error on a cache miss
- [x] 1.5 Add the **Keyless consumer reads the shared cache without a decision or a fetch** and **Keyless cache miss is not reported as an auth failure** scenarios
- [x] 1.6 Add both scenarios to `acceptance/private/flag-definition-loader.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/flag-definition-loader/spec.md` and archive the change
