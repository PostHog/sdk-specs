# Tasks

## 1. Correct the spec
- [x] 1.1 Re-audit `posthog-js` `main` bootstrap flag + identity behavior against the spec, capturing exact line refs.
- [x] 1.2 Modify the flag-load requirement: complete responses replace; partial/`errorsWhileComputingFlags` merge; stale-payload consequence.
- [x] 1.3 Modify the flag-serving requirement: bootstrap snapshot wins over persisted flags, applied every init.
- [x] 1.4 Modify the `$feature_flag_called` reporting requirement: latch set after any successful `/flags` 200.
- [x] 1.5 Modify the reconciliation requirement: identity persists while opted out.
- [x] 1.6 Add the matching-id identified-bootstrap upgrade requirement.

## 2. Correct the acceptance tests
- [x] 2.1 Update `acceptance/public/bootstrap.feature` scenarios to match the corrected requirements (replace-on-complete-load, drop bootstrapped-only keys, stale-payload replaced, partial/errored merge, bootstrap-wins-over-persisted, matching-id upgrade, opt-out reconciliation, partial-load `$used_bootstrap_value`).
- [ ] 2.2 Harness step definitions to add for the new scenarios: `persistent storage contains feature flags:`, `feature flags are loaded with errors while computing and values:`, `the returned feature flag payload for <key> should be null`, `no event named "<name>" should be enqueued`, `no events should be enqueued`.

## 3. Validate and archive
- [x] 3.1 `openspec validate fix-bootstrap-js-parity --strict` passes.
- [ ] 3.2 Cross-SDK review (js/android/flutter owners) sign-off before `openspec archive` syncs the delta into the main spec.
