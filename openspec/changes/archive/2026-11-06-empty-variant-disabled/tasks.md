## 1. Spec delta

- [x] 1.1 Add the **Empty variant reads as disabled** requirement to `get-feature-flag-result`, and describe empty variants in its client and server flows
- [x] 1.2 Say "non-empty variant string" in the `is-feature-enabled` server-side flow
- [x] 1.3 Add the scenario to `acceptance/public/get-feature-flag-result.feature`
- [x] 1.4 Add the **Empty variant is left out of the flags a listener receives** requirement to `on-feature-flags` and its scenario to `acceptance/public/on-feature-flags.feature`
- [x] 1.5 Add the **Empty variant is not an active feature flag** requirement to `capture` and its scenario to `acceptance/public/capture.feature`
- [x] 1.6 Add the **Flag result list reads an empty variant as disabled** requirement to `get-feature-flags` and its scenario to `acceptance/public/get-feature-flags.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --strict`
- [x] 2.2 Sync the delta into `specs/` and archive the change
