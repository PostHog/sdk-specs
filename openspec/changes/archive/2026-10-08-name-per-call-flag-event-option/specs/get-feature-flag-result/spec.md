## Narrative alignment

When syncing this delta, correct the Flutter surface variant to `getFeatureFlagResult(key, { sendFeatureFlagEvent = true }): Future<PostHogFeatureFlagResult?>` (6.0+).

Two other specs carry the same stale facts and SHALL be corrected in the same sync:

- `feature-flag-called-tracker`, Behavior step 6: Flutter's per-call suppression flag is `getFeatureFlagResult(sendFeatureFlagEvent: ...)`, not `sendEvent`.
- `opt-in`, Surface variants: add `**Flutter:** optIn() / optOut()`, noting that `enable()` / `disable()` were deprecated in 5.x and removed in 6.0.

## ADDED Requirements

### Requirement: Per-call feature flag event option name

A flag-reading API that lets the caller suppress `$feature_flag_called` for that call SHALL name the option `sendFeatureFlagEvent` on client SDKs and `sendFeatureFlagEvents` on server SDKs, adapted to platform casing (for example `send_feature_flag_event`). The singular form governs one call's event; the plural form governs event sending across a server-side evaluation that may emit several. The option SHALL default to sending the event.

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
