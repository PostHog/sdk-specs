## ADDED Requirements

### Requirement: Client-level feature flag event default

A client SDK that exposes a client-level feature flag event configuration option (`sendFeatureFlagEvent`, in platform casing) SHALL apply it to every flag read that can emit `$feature_flag_called`, including the value getter, the enablement getter, and the structured result getter.

Each read SHALL decide whether to emit in this order: the per-call option when the caller supplied one, then the client-level configuration value, then `true`. A read SHALL NOT default its per-call option to `true` and thereby bypass a disabled client-level configuration. A wrapper SDK that forwards the read to an underlying native or browser SDK SHALL omit the per-call override when the caller supplied none, so the underlying SDK applies its own configured default. Payload-only getters that never emit `$feature_flag_called` take no option and are unaffected.

When the decision is `false`, the read SHALL emit no `$feature_flag_called` event and SHALL NOT consult or update the dedupe tracker, so a later opted-in read of the same flag and value still emits.

#### Scenario: Client-level event default off silences flag reads (@client @requires:flag_event_default)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and its client-level feature flag event default disabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called
- **AND** get feature flag "beta-ui" is called
- **AND** is feature enabled "beta-ui" is called
- **THEN** no event named "$feature_flag_called" should be enqueued

#### Scenario: Per-call tracking option overrides a disabled client-level default (@client @requires:flag_event_default)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and its client-level feature flag event default disabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called with tracking enabled
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

#### Scenario: Suppressed read leaves the dedupe tracker untouched (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called with tracking disabled
- **AND** get feature flag result "beta-ui" is called
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"
