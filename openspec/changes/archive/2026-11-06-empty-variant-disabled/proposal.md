## Why

A flag whose variant is the empty string `""` reads as disabled from `isFeatureEnabled` in posthog-js (browser) and posthog-android, and in posthog-ios since [posthog-ios#1001](https://github.com/PostHog/posthog-ios/pull/1001). The same SDKs still report it as `enabled: true` from `getFeatureFlagResult`, and some include it in the flags-loaded callback, so one flag reads as both enabled and disabled depending on the call ([review thread](https://github.com/PostHog/posthog-ios/pull/1001#discussion_r4449050127)). posthog-js (browser) is consistent: `""` is disabled everywhere.

PostHog has rejected new `""` variant keys since [PostHog/posthog#118803](https://github.com/PostHog/posthog/pull/118803) (2026-10-16), so only flags created earlier through the API, MCP or Terraform can hit this.

The client-side flow of `is-feature-enabled` already says only a non-empty variant string is `true`. The server-side flow, `get-feature-flag-result`, `on-feature-flags` and the `$active_feature_flags` event property don't say what an empty variant is.

## What Changes

- **`is-feature-enabled`.** The server-side flow treats only a non-empty variant string as `true`, matching the client-side flow.
- **`get-feature-flag-result`.** A new requirement: a flag whose variant is `""` returns `enabled: false` with `variant: ""`, and `is-feature-enabled` returns `false` for it. Both flow descriptions say so.
- **`on-feature-flags`.** A new requirement: payload-carrying listeners leave a `""` flag out of the keys and variants they receive.
- **`get-feature-flags`.** A new requirement: where `getAllFeatureFlags()` returns flag result objects, a `""` flag stays in the list with `enabled: false`, matching `get-feature-flag-result`.
- **`capture`.** A new requirement: client SDKs leave a `""` flag out of `$active_feature_flags`; `$feature/<key>` still carries `""`.
- **Stale surface notes.** `reload-feature-flags` lists the Android 4.0 and Flutter 6.0 signatures, and `feature-flag-called-tracker` says Flutter 6.0 adds `sendFeatureFlagEvent` to `getFeatureFlag` and `isFeatureEnabled`. No requirement changes.
- **Acceptance.** Matching scenarios in `acceptance/public/get-feature-flag-result.feature`, `on-feature-flags.feature`, `get-feature-flags.feature` and `capture.feature`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `get-feature-flag-result`: new **Empty variant reads as disabled** requirement, and the client and server flow descriptions.
- `on-feature-flags`: new **Empty variant is left out of the flags a listener receives** requirement.
- `get-feature-flags`: new **Flag result list reads an empty variant as disabled** requirement.
- `capture`: new **Empty variant is not an active feature flag** requirement.
- `is-feature-enabled`: the server-side flow description only (recorded in the `get-feature-flag-result` delta, since it has no requirement changes).

## Impact

- posthog-ios 4.0, posthog-android 4.0 and posthog-flutter 6.0 change `getFeatureFlagResult().enabled` and the `enabled` of each `getAllFeatureFlags()` entry (and Flutter desktop also `isFeatureEnabled`) to `false` for an empty variant in their major releases. posthog-ios 4.0 and posthog-android 4.0 also leave it out of `PostHogFeatureFlagsLoaded` (the `onFeatureFlags` and `reloadFeatureFlags` callback payload) and `$active_feature_flags`.
- posthog-kmp treats an empty variant as disabled in `isFeatureEnabled()`, `FeatureFlagResult.enabled`, `getAllFeatureFlags()` and `$active_feature_flags` on every platform, in the release that adopts posthog-ios 4.0 and posthog-android 4.0.
- Known gap: posthog-js core and react-native still return `enabled: true` from `getFeatureFlagResult` (`getEnabledFromValue` reads any string as enabled), still pass `""` to `onFeatureFlags` listeners, and still list it in `$active_feature_flags`, while their `isFeatureEnabled` returns `false`. A follow-up should align them.
- `getFeatureFlag` and the `$feature_flag_called` response keep reporting `""`.
- Server SDKs were not audited for this case.
