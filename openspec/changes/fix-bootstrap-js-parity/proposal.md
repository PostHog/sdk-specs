## Why

The `bootstrap` spec was extracted from the shipped `posthog-js` implementations as the canonical winner, but a re-audit against `posthog-js` `main` (`packages/browser/src/posthog-featureflags.ts`, `posthog-core.ts`) found five places where the spec drifted from the source it claims to mirror. The `posthog-ios` bootstrap PR ([#715](https://github.com/PostHog/posthog-ios/pull/715)) implemented the spec faithfully and so inherited the drift, and a reviewer familiar with `posthog-js`/`posthog-android` flagged the same five behaviors. This change corrects the spec (and its acceptance tests) to match the verified `posthog-js` behavior so all SDKs converge on the real canonical target.

## What Changes

- **Complete `/flags` responses replace, not merge.** `receivedFeatureFlags` (posthog-featureflags.ts:121-161) replaces the served flags and payloads on a complete response; it only merges for a partial response (`options.partialResponse`) or one with `errorsWhileComputingFlags`. The spec said bootstrapped-only keys survive a load, which is the opposite. Corrected, including the consequence that a bootstrapped payload is not retained alongside a replaced flag value.
- **Bootstrap snapshot precedence over persisted flags.** `initialize()` (posthog-featureflags.ts:316-338) applies bootstrap via a complete `receivedFeatureFlags`, so bootstrap replaces a persisted cache (bootstrap wins) and is applied on every init while configured, not just first install. The spec was silent; added.
- **Matching-id identified bootstrap marks the user identified.** The bootstrap `else` branch (posthog-core.ts:781-792) sets `USER_STATE_IDENTIFIED` when the bootstrap id equals the existing id. The spec's reconciliation only covered a differing id. Added.
- **Identity reconciliation persists while opted out.** `identify()` (posthog-core.ts:2511-2558) registers the distinct id and identified state before any capture, with no opt-out early return, so local identity is maintained while opted out (only event emission is suppressed). The spec was silent; added.
- **`$used_bootstrap_value` latch is set after any successful `/flags` response.** `_flagsLoadedFromRemote = !errorsLoading` (posthog-featureflags.ts:647) is set on any HTTP 200 including `errorsWhileComputingFlags` (tracked separately at :663), and `$used_bootstrap_value = !_flagsLoadedFromRemote` (:848) is global. Tightened the ambiguous "has not yet received a /flags response" wording to say any successful response, including a partial/errored one.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bootstrap`: corrects the flag-load precedence model (complete responses replace; partial/errored merge), the bootstrap-vs-persisted precedence, the identity reconciliation for a matching id and while opted out, and the `$used_bootstrap_value` latch semantics.

## Impact

- `openspec/specs/bootstrap/spec.md` and `acceptance/public/bootstrap.feature` are corrected to match `posthog-js`.
- `posthog-ios` PR #715 must be re-implemented to the corrected spec (drop the base-layer merge, make bootstrap a replace snapshot, revert the complete-only latch change, and handle the matching-id and opt-out reconciliation cases).
- `posthog-android` and `posthog-flutter` targets now have a corrected target; where `posthog-android` already matches `posthog-js` it needs no change.
- Interacts with the `feature-flag-cache`, `get-feature-flag`, `get-feature-flag-payload`, `feature-flag-called-tracker`, `identify`, `opt-in-out`, and `reset` specs.
