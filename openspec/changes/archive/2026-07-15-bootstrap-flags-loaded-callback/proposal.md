## Why

`posthog-js` fires the flags-loaded callback (`onFeatureFlags`) the moment bootstrap flags are applied. `initialize()` (`posthog-featureflags.ts:316-338`) calls `receivedFeatureFlags(...)` with the bootstrapped flags, which sets `_hasLoadedFlags = true` and runs `_fireFeatureFlagsCallbacks(...)` (`posthog-featureflags.ts:983-1005`). So a listener waiting on flags is unblocked immediately from bootstrap, before any `/flags` response; a later response fires it again with the loaded values.

The bootstrap spec covered the served *values* but not this callback timing, so an SDK could apply the bootstrap snapshot silently and only fire the callback after the first network response. `posthog-ios` and `posthog-android` both did exactly that: the snapshot was seeded at setup but the flags-loaded notification only fired after the `/flags` (or `/config`) round-trip, blocking listeners on the network even though the served values were already available.

## What Changes

- Add a requirement to the `bootstrap` capability: when bootstrap feature flags are applied at setup, the SDK fires its flags-loaded callback/notification with the served bootstrapped flags, before and independently of the first `/flags` response. A later `/flags` response fires it again with the loaded values.
- Add an acceptance scenario covering the setup-time callback firing.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bootstrap`: gains a requirement that applying bootstrap feature flags fires the flags-loaded callback at setup.

## Impact

- `openspec/specs/bootstrap/spec.md` and `acceptance/public/bootstrap.feature` gain the callback-firing requirement and scenario.
- `posthog-ios` PR #715 fires `notifyFeatureFlags` when the bootstrap snapshot is seeded at `PostHogRemoteConfig.init`.
- `posthog-android` fires the flags-loaded callbacks in `setup` when the bootstrap snapshot was applied, before the network reload.
