## Why

The canonical server snapshot API is already specified, but its acceptance scenarios are not connected to real Node executions. Remote evaluation, public snapshot getters, and exposure delivery should be verified through the public SDK and mock-service traffic.

## What Changes

- Add observable server executions to the existing evaluate-flags feature for shared evaluation, scalar/rich flag projections, exposure presence and dedupe, silent payload/key reads, fresh request contexts, evaluation option forwarding, nonempty/empty request-time key scopes, request-local explicit-key/accessed-key filtering, supported caller defaults, and safe-empty snapshots for missing identity, disabled SDK, and remote failure.
- Use a request-scoped compound adapter operation, `/evaluate_flags/read`, which invokes the public evaluation method once, calls the requested public getters and snapshot filters in order, and returns the observed public outcomes.
- Explicitly flush through the public SDK before asserting delivered exposure events or non-delivery. Cover enabled, variant, disabled, and missing-key accesses, with canonical responses and missing-key error metadata. Observe remote evaluation requests directly.
- Exercise supported enablement defaults without overriding present flag values, and safe public reads from empty snapshots. Use public SDK configuration to disable flag-request retries in the controlled failure case.
- Compare public semantic projections across scalar getters and rich result fields/methods, including documented payload representations and native missing values.
- Preserve existing authored scenarios and their legacy applicability. Earn `@sdk:server` selection through real Node execution before tagging the new cases.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: add executable remote-read and exposure-delivery scenarios for the existing snapshot behavior. Public SDK signatures and snapshot semantics remain unchanged.

## Impact

- sdk-specs: existing `acceptance/public/evaluate-flags.feature`, canonical evaluate-flags spec, README, and archived OpenSpec history.
- Shared harness: compound-operation steps and outcome/traffic assertions, controlled-host regressions, bundled-suite expectations, documentation, and a minor changeset.
- Node: compliance adapter mapping, native argument/method spies, installed-package HTTP tests, and adapter documentation. SDK production code is unchanged.
- Stack within each repository above sdk-specs #105, harness #75, and posthog-js #5232; cross-link the follow-ups. Release pins and image publication remain a separate rollout.

## Non-goals

Local definitions/fallback, malformed payloads, cache/refresh/concurrency behavior, runtime filtering, snapshot-enriched capture, cross-request snapshot retention, standalone compatibility getter coverage, and general capture delivery remain outside this slice.
