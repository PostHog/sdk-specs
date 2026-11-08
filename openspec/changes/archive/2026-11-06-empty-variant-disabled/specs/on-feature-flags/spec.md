## ADDED Requirements

### Requirement: Empty variant is left out of the flags a listener receives

A payload-carrying listener SHALL treat a flag whose value is the empty string `""` as disabled and leave it out of the flag keys and variants it receives, like a flag whose value is `false`. Readiness-only listeners are not affected.

Known gap: posthog-js core and react-native pass the raw flag map, which still contains the `""` entry. A follow-up should drop it there.

#### Scenario: Listener does not receive an empty variant flag
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** feature flags are loaded with values:
  | key       | value |
  | beta-ui   | true  |
  | legacy-ui | ""    |
- **THEN** the feature flag listener should be invoked
- **AND** payload-carrying feature flag listeners should receive flags:
  | key     | value |
  | beta-ui | true  |
- **AND** payload-carrying feature flag listeners should not receive flag "legacy-ui"
