## Why

posthog_flutter 6.0 ([PostHog/posthog-flutter#637](https://github.com/PostHog/posthog-flutter/pull/637)) removes the Flutter APIs that several specs still name, and changes what Flutter's `beforeSend` callbacks see. The specs record Flutter's old surfaces, or mark the 6.0 changes as unreleased.

## What Changes

- `before-send-hook`: record that Flutter 6.0 passes callbacks the native-built event on iOS, macOS and Android and the merged event on Windows and Linux, that only Flutter Web keeps the pre-enrichment subset, and that `PosthogFlutterPlugin.addBeforeSend` reaches native-initiated events.
- `consent-gating`: name Flutter's `optOut()` instead of the removed `disable()`.
- `opt-in`: record the `enable()` / `disable()` removal as shipped in 6.0.
- `remote-config`: name `sendFeatureFlagEvent` and the `Posthog().onFeatureFlags(callback)` listener instead of the removed `sendFeatureFlagEvents` and config callback.
- `flag-definition-loader`: name `projectToken` instead of the removed `apiKey`.
- `get-feature-flag-payload`, `local-feature-flag-evaluator`, `feature-flag-called-tracker`: record that Flutter 6.0 removes `getFeatureFlagPayload`.
- `get-feature-flag-result`: record Flutter 6.0's `sendFeatureFlagEvent` option and its fallback to `PostHogConfig.sendFeatureFlagEvent`, and update the recorded-divergence sentence in the option-name requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `before-send-hook`, `consent-gating`, `opt-in`, `remote-config`, `flag-definition-loader`, `get-feature-flag-payload`, `local-feature-flag-evaluator`, `feature-flag-called-tracker`, `get-feature-flag-result`: surface variants and narrative only. No requirement changes meaning; the `get-feature-flag-result` requirement only updates which Flutter version carries the recorded divergence.

## Impact

No SDK has to change. It records posthog-flutter#637 and the PRs stacked on it (#638, #647, #662, #682, #686, #695).
