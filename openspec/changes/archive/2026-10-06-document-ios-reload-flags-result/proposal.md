## Why

posthog-ios 4.0 ([posthog-ios #913](https://github.com/PostHog/posthog-ios/pull/913)) passes a `PostHogFeatureFlagsLoaded` (`flags`, `variants`, `errorsLoading`) to the `reloadFeatureFlags(_:)` completion callback, so callers can tell a failed reload from a successful one. The spec's iOS surface variant still lists the zero-argument callback, and the spec says only that failure reporting is SDK-specific, without stating what a reported failure must mean.

## What Changes

- Update the iOS surface variant to `reloadFeatureFlags(_ callback: @escaping (PostHogFeatureFlagsLoaded) -> Void)` (4.0+).
- Add an optional requirement: SDKs MAY report load failure through the reload completion; when they do, it MUST reflect whether that reload's request failed and carry the last known flags on failure.
- Note in Error handling that iOS reports the same `{ flags, variants, errorsLoading }` shape as `onFeatureFlags`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `reload-feature-flags`: document optional completion-callback failure reporting and the iOS 4.0 signature.

## Impact

No SDK is required to change. The canonical `(flags?, error?: Error)` signature is unchanged; iOS reuses the `on-feature-flags` context shape instead of an `Error`, which the existing "depending on SDK" wording already permits.
