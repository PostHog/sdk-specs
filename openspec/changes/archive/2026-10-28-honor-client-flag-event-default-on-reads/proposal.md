## Why

Client SDKs expose a client-level `sendFeatureFlagEvent` configuration option that turns
`$feature_flag_called` off for the whole SDK, and a per-call option on the flag getters. No
requirement says how the two combine, so `feature-flag-called-tracker` behavior item 6 is the only
statement on the subject and it describes a single wrapper's older shape.

That gap produced a real divergence. posthog-flutter's `getFeatureFlagResult()` defaulted its
per-call `sendFeatureFlagEvent` to `true` and always forwarded it, so an app with
`PostHogConfig.sendFeatureFlagEvent = false` still captured `$feature_flag_called` from every
structured-result read while `getFeatureFlag()` and `isFeatureEnabled()` stayed silent. The SDKs it
forwards to resolve the per-call value against the config instead:

| SDK | Resolution | Source |
|---|---|---|
| posthog-ios | `sendFeatureFlagEvent ?? config.sendFeatureFlagEvent` | `PostHog/PostHogSDK.swift:2533` |
| posthog-android | `sendFeatureFlagEvent ?: config?.sendFeatureFlagEvent` | `posthog/src/main/java/com/posthog/PostHog.kt:2023-2025` |
| posthog-flutter | per-call option is now `bool?`, `null` follows the config on every platform | PostHog/posthog-flutter#662 |

Both iOS and Android run the dedupe tracker only after deciding to emit, so a suppressed read
leaves the tracker untouched and a later opted-in read of the same flag and value still emits.
That matches the per-read rule #111 proposes for server snapshot reads.

Behavior item 6 is also stale: posthog-flutter now takes a per-call option on `getFeatureFlag()`
and `isFeatureEnabled()` as well (PostHog/posthog-flutter#666), not only on
`getFeatureFlagResult()`.

## What Changes

- New requirement **Client-level feature flag event default** in `feature-flag-called-tracker`:
  a read decides by the per-call option, then the client-level configuration, then `true`; a read
  SHALL NOT default its per-call option to `true` and bypass a disabled configuration; a wrapper
  forwarding the read omits the override when the caller supplied none; a suppressed read neither
  consults nor updates the dedupe tracker.
- Three scenarios, two of them tagged `@requires:flag_event_default` because only some client SDKs
  expose a client-level default.
- Behavior item 6 drops the claim that Flutter exposes per-call suppression only on
  `getFeatureFlagResult`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `feature-flag-called-tracker`: new **Client-level feature flag event default** requirement.

## Impact

- **posthog-ios, posthog-android**: already conform.
- **posthog-flutter**: conforms from #662 onward; the 5.x behavior is the divergence this records.
- **Client SDKs with no client-level default** (posthog-js today): unaffected, the
  `@requires:flag_event_default` scenarios do not apply to them.
- **Acceptance adapters**: two new steps, `get feature flag result "<key>" is called with tracking
  disabled` and `... with tracking enabled`, modelled on the existing
  `get feature flag "<key>" is called with tracking disabled`. The harness needs bindings for them.
