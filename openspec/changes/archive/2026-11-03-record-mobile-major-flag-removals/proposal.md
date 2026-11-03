## Why

posthog-ios 4.0, posthog-android 4.0 and posthog_flutter 6.0 remove `getFeatureFlagPayload`, so the `get-feature-flag-payload` requirement no longer has a mobile method to bind. A few flag specs also still describe the mobile SDKs' pre-major surfaces. Follows `align-mobile-flag-api-surfaces`.

## What Changes

- `get-feature-flag-payload`: record the removals and add a requirement that SDKs without a payload getter meet the payload scenarios through a silent flag result read (`getFeatureFlagResult(key, sendFeatureFlagEvent: false)` and its payload).
- `get-feature-flags`, `get-feature-flags-and-payloads`: record the mobile `getAllFeatureFlags()` that returns flag result objects.
- `get-feature-flag`: record Flutter 6.0's `sendFeatureFlagEvent` option.
- `feature-flag-cache`, `feature-flag-called-tracker`: record that Flutter's pure-Dart client on macOS, Windows and Linux owns its cache and tracker. Flutter's per-call option on flag reads is left to #153.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-payload`: one added requirement.
- `get-feature-flags`, `get-feature-flags-and-payloads`, `get-feature-flag`, `feature-flag-cache`, `feature-flag-called-tracker`: surface variants and narrative only.

## Impact

No SDK has to change because of this. It records the removals in PostHog/posthog-ios#873, PostHog/posthog-android#871 and PostHog/posthog-flutter#637.
