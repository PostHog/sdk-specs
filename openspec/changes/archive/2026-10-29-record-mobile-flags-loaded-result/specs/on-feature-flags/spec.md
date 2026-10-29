## Narrative alignment

When syncing this delta, replace the Android and Flutter entries in **Surface variants** with:

- **Android:** `PostHogConfig.onFeatureFlags = PostHogFeatureFlagsCallback` and
  `reloadFeatureFlags(PostHogFeatureFlagsCallback?)` (4.0+), where `loaded(...)` receives a
  `PostHogFeatureFlagsLoaded` carrying the enabled flag keys, their variants, and `errorsLoading`.
  Before 4.0 the callback was `PostHogOnFeatureFlags`, which took no arguments.
- **Flutter:** `PostHogConfig(onFeatureFlags: void Function(PostHogFeatureFlagsLoaded))` /
  `config.onFeatureFlags = ...` during `setup(...)` (6.0+), with the same three fields on every
  platform the plugin bridges. Before 6.0 the callback was `void Function()`.

In **Behavior** item 4, group Android (4.0+) and Flutter (6.0+) with browser and iOS as both
payload-carrying and error-aware surfaces. Leave Unity as the readiness-only surface, and note that
Android before 4.0 and Flutter before 6.0 were readiness-only too. Leave item 5 unchanged: carrying
a payload is not the same as replaying the current values to a late-registered listener, and neither
SDK is recorded as doing that.

In **Lifecycle behavior**, keep the note that Flutter maps native/browser flag-loaded signals into a
Dart `onFeatureFlags` callback, and add that from 6.0 it maps the native result's values and error
state into the Dart result rather than dropping them.

## ADDED Requirements

### Requirement: Flags-loaded result on a payload-carrying listener

A payload-carrying flag-loaded listener SHALL receive, in the SDK's documented representation, all
three of: the keys of the enabled flags, the value of each enabled flag (`true` or its variant
string), and whether the latest load failed. The representation MAY be one result object (posthog-ios
4.0, posthog-android 4.0 and posthog-flutter 6.0 each pass a `PostHogFeatureFlagsLoaded` with
`flags`, `variants` and `errorsLoading`) or separate arguments (posthog-js passes the flag keys, the
variants, and a context carrying `errorsLoading`). This spec does not require one argument list
across platforms.

In the `PostHogFeatureFlagsLoaded` shape, a disabled flag SHALL be omitted from both `flags` and
`variants` rather than carried with a `false` value, so an empty result and "every flag is off" are
the same observation. An SDK using that shape SHALL NOT report a disabled flag as enabled to make
the two distinguishable; a caller that needs the full map reads it through the getter APIs.

The listener SHALL receive a result that describes the load that triggered it on every invocation
path, not only on a successful remote load. A path that serves cached, bootstrapped or last-known
values SHALL carry those values, and a path on which the load failed SHALL report the failure rather
than present the retained values as freshly loaded. An SDK SHALL NOT substitute an empty or
synthesized success for a result it cannot determine.

#### Scenario: Listener result carries the enabled flags and their variants
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** feature flags are loaded with values:
  | key        | value   |
  | beta-ui    | true    |
  | new-layout | variant |
- **THEN** payload-carrying feature flag listeners should receive flags:
  | key        | value   |
  | beta-ui    | true    |
  | new-layout | variant |
- **AND** error-aware feature flag listeners should not be told that loading flags errored

#### Scenario: A disabled flag is left out of the listener result
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK passes its flag-loaded result as a `PostHogFeatureFlagsLoaded`
- **AND** a feature flag listener is registered
- **WHEN** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
  | old-ui  | false |
- **THEN** payload-carrying feature flag listeners should receive flags:
  | key     | value |
  | beta-ui | true  |
- **AND** the result should not contain "old-ui"
