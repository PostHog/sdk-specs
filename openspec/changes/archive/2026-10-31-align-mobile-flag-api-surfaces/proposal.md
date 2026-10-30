## Why

The mobile majors (posthog-ios 4.0, posthog-android 4.0, posthog_flutter 6.0) align their flag APIs, and three specs still describe the old surfaces.

## What Changes

- `on-feature-flags`: record that posthog-android 4.0 and posthog_flutter 6.0 remove `PostHogConfig.onFeatureFlags`, and that Flutter 6.0 has the method-style listener. Both join the payload-carrying, replaying group.
- `get-feature-flag`: record that posthog-android 4.0 removes `defaultValue`.
- `is-feature-enabled`: record the `defaultValue` overloads on iOS and Flutter that the existing requirement already needs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `on-feature-flags`, `get-feature-flag`, `is-feature-enabled`: surface variants and narrative only. No requirement changes meaning.

## Impact

No SDK has to change because of this. It records posthog-android#917, posthog-ios#1001, posthog-flutter#694 and the config-field removal PRs.
