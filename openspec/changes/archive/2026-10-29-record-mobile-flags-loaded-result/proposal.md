## Why

The `on-feature-flags` spec says Android and Flutter "primarily expose a readiness signal with no
direct payload; callers re-read flags through getter APIs when notified", and lists their surfaces
as payload-free. Both SDKs have changed that in their next majors.

- posthog-android 4.0 ([posthog-android#877](https://github.com/PostHog/posthog-android/pull/877))
  replaces `PostHogOnFeatureFlags` with `PostHogFeatureFlagsCallback`, whose `loaded(...)` receives
  a `PostHogFeatureFlagsLoaded` carrying `flags`, `variants` and `errorsLoading`. Both
  `PostHogConfig.onFeatureFlags` and `reloadFeatureFlags(...)` take the new callback.
- posthog-flutter 6.0 ([posthog-flutter#664](https://github.com/PostHog/posthog-flutter/pull/664))
  changes `PostHogConfig.onFeatureFlags` from `void Function()` to
  `void Function(PostHogFeatureFlagsLoaded)` and `reloadFeatureFlags()` from `Future<void>` to
  `Future<PostHogFeatureFlagsLoaded>`, with the same three fields on every platform it bridges.

Both cite posthog-ios 4.0's `PostHogFeatureFlagsLoaded`, which the spec already records, as the
shape they are converging on. So the readiness-only classification is now wrong for two of the three
SDKs it names, and the failed-load scenario's `payload-carrying` / `error-aware` listener classes no
longer describe who they should.

## What Changes

- `on-feature-flags`: move Android (4.0+) and Flutter (6.0+) from the readiness-only group into the
  payload-carrying and error-aware groups, and update their surface variants.
- `on-feature-flags`: add a requirement stating what a payload-carrying listener's result must
  carry, and that the result is passed on every invocation rather than only on a successful load.
- `reload-feature-flags`: update the Android and Flutter surface variants and the Error-handling
  note, and widen the existing "Reload completion failure reporting" requirement beyond iOS.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `on-feature-flags`: Android and Flutter become payload-carrying and error-aware; the result shape
  is stated.
- `reload-feature-flags`: Android and Flutter join iOS as SDKs that report the outcome through the
  reload completion.

## Impact

No SDK that already carries a payload has to change. Unity keeps the readiness-only classification.
posthog-js keeps its own `(flags, variants, context)` argument list; this change describes the
information a payload-carrying listener must carry, not one argument list for every platform.
