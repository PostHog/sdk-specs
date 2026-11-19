## Why

The `surveys` spec says the subsystem is installed "when surveys are enabled by local config
and/or remote config", but never says what that local config defaults to. Every client SDK had
already settled on enabled, and the two that had not now agree:

- PostHog/posthog-android#984 (merged 2026-11-16 as `36253029f`, on the 4.0 branch) flips
  `PostHogConfig.surveys` from `false` to `true`. Android was the only SDK defaulting it off.
- PostHog/posthog-kmp#125 (merged 2026-11-16) adds `surveys` to `PostHogConfig` with a `true`
  default, turning on the native Android surveys through the same switch.

The other SDKs read on 2026-11-17 already default to enabled: posthog-ios (`_surveys = true` in
`PostHogConfig.swift`), posthog-flutter (`var surveys = true` in `posthog_config.dart`),
posthog-js browser (`disable_surveys: false` in the config defaults) and posthog-js core, which
posthog-react-native inherits (`disableSurveys` documented `@default false`).

So the default is contractual, cross-SDK and unwritten. An SDK author reading the spec today has
nothing to tell them which way to ship a new local switch.

## What Changes

- **`surveys`**: a new requirement, **The local surveys option defaults to enabled**. A client
  SDK's local surveys switch (`surveys`, or an inverted `disableSurveys` / `disable_surveys`)
  defaults to enabled, so remote config and project settings decide whether a survey is
  delivered. An explicit local off still disables the subsystem.
- The requirement also records why defaulting on is safe where an application installs the
  survey renderer separately: with only a no-op delegate, the SDK keeps the loaded definitions
  and skips eligibility matching, so no `$feature_flag_called` is emitted for a survey's linked
  flag and no survey property filters run on captured events for a survey nobody can see. That
  rule is verified on posthog-android only and is flagged for review.
- Three scenarios.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: record the default of the local surveys switch.

## Impact

Specifications only. Conformant as merged: posthog-ios, posthog-flutter, posthog-js (browser,
core, react-native), posthog-kmp, and posthog-android on the 4.0 branch. posthog-android 3.x
still defaults the switch off and conforms once 4.0 ships. posthog-unity and posthog-godot were
not audited.
