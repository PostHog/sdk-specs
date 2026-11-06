## Why

A flag whose variant is the empty string `""` reads as disabled from `isFeatureEnabled` in posthog-js (browser) and posthog-android, and in posthog-ios since [posthog-ios#1001](https://github.com/PostHog/posthog-ios/pull/1001). The same SDKs still report it as `enabled: true` from `getFeatureFlagResult`, and some include it in the flags-loaded callback, so one flag reads as both enabled and disabled depending on the call ([review thread](https://github.com/PostHog/posthog-ios/pull/1001#discussion_r4449050127)). posthog-js (browser) is consistent: `""` is disabled everywhere.

PostHog has rejected new `""` variant keys since [PostHog/posthog#118803](https://github.com/PostHog/posthog/pull/118803) (2026-10-16), so only flags created earlier through the API, MCP or Terraform can hit this.

The client-side flow of `is-feature-enabled` already says only a non-empty variant string is `true`. The server-side flow and `get-feature-flag-result` don't say what an empty variant is.

## What Changes

- **`is-feature-enabled`.** The server-side flow treats only a non-empty variant string as `true`, matching the client-side flow.
- **`get-feature-flag-result`.** A new requirement: a flag whose variant is `""` returns `enabled: false` with `variant: ""`, and `is-feature-enabled` returns `false` for it. Both flow descriptions say so.
- **Acceptance.** A matching scenario in `acceptance/public/get-feature-flag-result.feature`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `get-feature-flag-result`: new **Empty variant reads as disabled** requirement, and the client and server flow descriptions.
- `is-feature-enabled`: the server-side flow description only (recorded in the `get-feature-flag-result` delta, since it has no requirement changes).

## Impact

- posthog-ios 4.0, posthog-android 4.0 and posthog-flutter 6.0 change `getFeatureFlagResult().enabled` (and Flutter desktop also `isFeatureEnabled`) to `false` for an empty variant in their major releases.
- `getFeatureFlag` and the `$feature_flag_called` response keep reporting `""`.
- Server SDKs were not audited for this case.
