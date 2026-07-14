## Why

Two SDKs — `posthog-js` (browser) and the shared `posthog-js` core that powers `react-native` and `node` — let callers seed identity and feature flags at init time via a `bootstrap` option, so the first events carry a known distinct id and `getFeatureFlag()` returns real values before the `/flags` request completes. This behavior is real and shipped, but no spec describes it, so `posthog-android`, `posthog-ios`, and `posthog-flutter` have no support and no target to converge on. Existing specs already lean on the concept — `feature-flag-cache` calls bootstrap an override layer, and `remote-config` lists "feature-flag bootstrapping decisions" as an input — without anything defining it.

## What Changes

- Add a new `bootstrap` capability spec, derived from the shipped `posthog-js` browser and core implementations as the canonical winner.
- Specify the config surface: `distinctId`, `isIdentifiedId`, `featureFlags`, `featureFlagPayloads`, and browser-only `sessionID`. Treat the field names as semantic — spelled per platform convention — so the browser (`distinctID`) vs. core (`distinctId`) casing is expected rather than a divergence to resolve.
- Specify identity bootstrap: seed persisted identity only when none exists, never overwrite; `isIdentifiedId` marks the person as identified — seeding only the distinct id, never the device/anonymous id — otherwise anonymous.
- Specify identity reconciliation as canonical (with a non-overwrite fallback for SDKs that cannot merge at init): merge an anonymous local user into a bootstrapped identified id via `identify()`, and preserve-with-warning when a different identified id already exists.
- Specify feature-flag bootstrap: serve bootstrapped values immediately, layer them as the base under any persisted/loaded flags so a fresh `/flags` response wins, and store the bootstrapped copy for later reference; bootstrap is first-session only — dropped on `reset()` (along with the `$used_bootstrap_value` signal) so it never re-applies to a new user.
- Specify the `$feature_flag_called` enrichment: `$feature_flag_bootstrapped_response`, `$feature_flag_bootstrapped_payload`, and `$used_bootstrap_value` (true until `/flags` has been hit).
- Specify browser-only session bootstrap: accept a UUIDv7 `sessionID` to continue a session across domain/device, deriving session start from the UUID timestamp; fall back to a generated id when invalid.
- Note explicitly that mobile SDKs have no bootstrap support today and this spec is their target.

## Capabilities

### New Capabilities

- `bootstrap`: Seeding distinct id, person-identification state, feature flags/payloads, and (browser) session id at SDK init so early events and flag reads use known values before the first network response.

### Modified Capabilities

None. The `feature-flag-cache` and `remote-config` specs already reference bootstrap as an external layer; this change defines that layer without altering their requirements.

## Impact

- Target implementations that gain a canonical contract: `posthog-android`, `posthog-ios`, `posthog-flutter` (no support today); `posthog-js` browser and core already match.
- Interacts with the `setup`, `feature-flag-cache`, `get-feature-flag`, `get-feature-flag-payload`, `get-feature-flag-result`, `feature-flag-called-tracker`, `identify`, `reset`, `session-manager`, and `remote-config` specs.
- Adds acceptance coverage for bootstrapped identity precedence, flag serving before `/flags`, and the `$used_bootstrap_value` transition.
