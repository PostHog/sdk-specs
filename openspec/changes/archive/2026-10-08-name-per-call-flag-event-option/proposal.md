## Why

posthog-flutter 6.0 ([#636](https://github.com/PostHog/posthog-flutter/pull/636) deprecated, [#638](https://github.com/PostHog/posthog-flutter/pull/638) removed) renamed three public names onto the ones the other SDKs already use: `enable()`/`disable()` became `optIn()`/`optOut()`, and the per-call `getFeatureFlagResult(sendEvent:)` option became `sendFeatureFlagEvent` ([#647](https://github.com/PostHog/posthog-flutter/pull/647)). Flutter was the last client SDK naming the per-call option differently.

Three places in the specs still describe the old names, so they are now simply wrong:

- `get-feature-flag-result` lists the Flutter variant as `getFeatureFlagResult(key, { sendEvent = true })`.
- `feature-flag-called-tracker` cites `getFeatureFlagResult(sendEvent: ...)` as Flutter's per-call suppression flag.
- `opt-in` lists no Flutter surface variant at all.

The specs also never state what the per-call option is called, which is why the Flutter divergence went unrecorded for as long as it did.

## What Changes

- Add a requirement naming the per-call feature-flag-event option: singular `sendFeatureFlagEvent` on client SDKs, plural `sendFeatureFlagEvents` on server SDKs, in platform casing.
- Correct the Flutter surface variant in `get-feature-flag-result` and the Flutter note in `feature-flag-called-tracker`.
- Add the Flutter surface variant to `opt-in`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-result`: name the per-call feature-flag-event option and correct the Flutter variant.

## Impact

No SDK is required to change; this records names every audited SDK already ships. The client/server split (singular vs plural) is the existing state, not a new rule: client SDKs suppress a single call's `$feature_flag_called`, while server SDKs configure event sending for a whole evaluation.
