## ADDED Requirements

### Requirement: Empty variant is not an active feature flag

When a client SDK stamps cached feature flags onto a captured event, a flag whose value is the empty string `""` SHALL NOT be listed in `$active_feature_flags`. Its `$feature/<key>` property SHALL still carry `""`.

Known gap: posthog-js core and react-native list every cached flag key in `$active_feature_flags`, including one whose value is `""`. A follow-up should leave it out there.

#### Scenario: Empty variant flag is left out of active feature flags (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | beta-ui   | true  |
  | legacy-ui | ""    |
- **WHEN** capture is called with event "Signed Up"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event property "$active_feature_flags" should contain "beta-ui"
- **AND** the enqueued event property "$active_feature_flags" should not contain "legacy-ui"
- **AND** the enqueued event property "$feature/legacy-ui" should equal ""
