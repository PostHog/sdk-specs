## Narrative alignment

When syncing this delta, note on the Flutter surface variant that released Flutter (5.x) takes `getFeatureFlagResult(key, { sendEvent = true })` and that Flutter 6.0 (unreleased) renames the option to `sendFeatureFlagEvent`.

Two other specs carry related Flutter facts and SHALL be updated in the same sync:

- `feature-flag-called-tracker`, Behavior step 6: Flutter's per-call suppression flag is `getFeatureFlagResult(sendEvent: ...)` in released 5.x, renamed `sendFeatureFlagEvent` in Flutter 6.0 (unreleased).
- `opt-in`, Surface variants: add `**Flutter:** optIn() / optOut()` (since 5.51.0), noting that `enable()` / `disable()` are deprecated since 5.51.0 and their removal is merged for Flutter 6.0 (unreleased).

## ADDED Requirements

### Requirement: Per-call feature flag event option name

A flag-reading API that lets the caller suppress `$feature_flag_called` for that call SHALL name the option `sendFeatureFlagEvent` on client SDKs and `sendFeatureFlagEvents` on server SDKs, adapted to platform casing (for example `send_feature_flag_event`). The singular form governs one call's event; the plural form governs event sending across a server-side evaluation that may emit several. On APIs that return a flag value or result, the option SHALL default to sending the event. Payload-only reads keep their silent default (see `get-feature-flag-payload`); the option name still applies there. Per-call names that shipped before this requirement are recorded divergences and are not required to change: posthog-js core and react-native take a per-call `sendEvent` option (`FeatureFlagResultOptions`); their `sendFeatureFlagEvent` is the instance-level client option, not a per-call one. posthog-js browser takes a per-call `send_event` option (`FeatureFlagOptions`). Released Flutter (5.x, latest 5.56.0) takes `getFeatureFlagResult(key, sendEvent:)`; the rename to `sendFeatureFlagEvent` is merged for Flutter 6.0 (unreleased).

#### Scenario: Suppressing the per-call option skips the flag called event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called with the feature flag event option disabled
- **THEN** the returned result value should be true
- **AND** no event named "$feature_flag_called" should be enqueued

#### Scenario: The per-call feature flag event option defaults to sending (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called without the feature flag event option
- **THEN** the returned result value should be true
- **AND** one event named "$feature_flag_called" should be enqueued
