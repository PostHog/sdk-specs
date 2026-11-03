## Why

posthog-flutter is converging three public names onto the ones iOS and Android use. `optIn()`/`optOut()` shipped in 5.51.0 with `enable()`/`disable()` deprecated ([#636](https://github.com/PostHog/posthog-flutter/pull/636)). The removal of `enable()`/`disable()` ([#638](https://github.com/PostHog/posthog-flutter/pull/638)) and the rename of the per-call `getFeatureFlagResult(sendEvent:)` option to `sendFeatureFlagEvent` ([#647](https://github.com/PostHog/posthog-flutter/pull/647)) are merged only into the `chore/v6-posthog-ios-4` branch for Flutter 6.0 (unreleased); released Flutter (latest 5.56.0) still takes `sendEvent`.

Flutter is not the only client SDK whose per-call option differs: posthog-js core and react-native take a per-call `sendEvent` option, and posthog-js browser takes `send_event`. In posthog-js core and react-native, `sendFeatureFlagEvent` is the instance-level client option, not a per-call one.

Three places in the specs need the Flutter facts stated precisely:

- `get-feature-flag-result` lists the Flutter variant as `getFeatureFlagResult(key, { sendEvent = true })`.
- `feature-flag-called-tracker` cites `getFeatureFlagResult(sendEvent: ...)` as Flutter's per-call suppression flag.
- `opt-in` lists no Flutter surface variant at all.

The specs also never state what the per-call option is called, which is why these divergences went unrecorded.

## What Changes

- Add a requirement naming the per-call feature-flag-event option: singular `sendFeatureFlagEvent` on client SDKs, plural `sendFeatureFlagEvents` on server SDKs, in platform casing. It records the shipped divergent names (posthog-js `sendEvent` / `send_event`, released Flutter `sendEvent`) as known divergences that are not required to change.
- Note the unreleased Flutter 6.0 rename on the Flutter surface variant in `get-feature-flag-result` and the Flutter note in `feature-flag-called-tracker`.
- Add the Flutter surface variant to `opt-in`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-result`: name the per-call feature-flag-event option and correct the Flutter variant.

## Impact

No SDK is required to change. iOS, Android, and the server SDKs already ship these names; posthog-js and released Flutter ship different per-call names, which the requirement records as known divergences rather than silently making them non-compliant. The client/server split (singular vs plural) is the existing state, not a new rule: client SDKs suppress a single call's `$feature_flag_called`, while server SDKs configure event sending for a whole evaluation.
