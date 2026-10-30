## Why

The `on-feature-flags` spec records Android's only listener surface as the config field
`PostHogConfig.onFeatureFlags` plus the `reloadFeatureFlags(...)` completion, and groups Android
with the SDKs that have no runtime registration surface. Behavior item 5 names browser and iOS as
the SDKs that invoke a listener registered after flags are already loaded, and leaves every other
SDK free to wait for the next load.

posthog-android 4.0 ([posthog-android#878](https://github.com/PostHog/posthog-android/pull/878))
changes that. It adds `PostHog.onFeatureFlags(PostHogFeatureFlagsCallback)`, on the instance and on
the static facade, returning a `PostHogFeatureFlagsSubscription` with `unsubscribe()`. It matches
posthog-ios 4.0's `onFeatureFlags(_:)` and posthog-js's `onFeatureFlags`, which the spec already
records as the method-style surfaces, and it was written against this spec's main-thread delivery
rule. So Android's surface-variant entry and its placement in item 5 are now wrong, and the spec
says nothing about how such a registration behaves across `reset()`, `close()` and re-`setup()`,
which is where the three SDKs' registration-based listeners differ from a single config field.

This is narrative drift plus one unrecorded behavior; the spec's existing "registered after flags
are ready" and "can be unsubscribed" scenarios already cover the generic contract.

## What Changes

- `on-feature-flags`: update the Android surface variant to record the 4.0 method-style
  registration and its subscription handle, and move Android's method-style listener into the
  group that replays the current values to a late-registered listener.
- `on-feature-flags`: add two requirements — a runtime listener registration's lifetime ends only
  at `unsubscribe()` and survives a `close()`/`setup()` cycle; and a load still in flight across
  `reset()` or `close()` reaches no listener.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `on-feature-flags`: Android 4.0 joins browser and iOS as a method-style, replaying registration
  surface; the lifetime of such a registration and the fate of a discarded load are stated.

## Impact

No SDK that already exposes a method-style registration has to change. SDKs that expose only a
config field (Flutter, Unity) are outside the registration-lifetime requirement; the discarded-load
requirement applies to any listener surface.
