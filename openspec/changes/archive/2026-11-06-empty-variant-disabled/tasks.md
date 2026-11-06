## 1. Spec delta

- [x] 1.1 Add the **Empty variant reads as disabled** requirement to `get-feature-flag-result`, and describe empty variants in its client and server flows
- [x] 1.2 Say "non-empty variant string" in the `is-feature-enabled` server-side flow
- [x] 1.3 Add the scenario to `acceptance/public/get-feature-flag-result.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --strict`
- [x] 2.2 Sync the delta into `specs/` and archive the change
