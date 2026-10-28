## 1. Spec delta

- [x] 1.1 Add the **Client-level feature flag event default** requirement to `feature-flag-called-tracker`
- [x] 1.2 State the per-call → client-level → `true` decision order and the wrapper pass-through rule
- [x] 1.3 State that a suppressed read neither consults nor updates the dedupe tracker
- [x] 1.4 Add the three scenarios to `acceptance/private/feature-flag-called-tracker.feature`
- [x] 1.5 Correct behavior item 6 so it no longer limits Flutter's per-call suppression to `getFeatureFlagResult`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/feature-flag-called-tracker/spec.md` and archive the change
