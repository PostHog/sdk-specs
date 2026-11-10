## ADDED Requirements

### Requirement: Flag result list reads an empty variant as disabled

On SDKs where `getAllFeatureFlags()` returns a list of flag result objects (iOS 4.0+, Android 4.0+, Flutter 6.0+, KMP), each entry SHALL match what `get-feature-flag-result` returns for that key. A flag whose value is the empty string `""` SHALL stay in the list with `enabled: false` and `variant: ""`. SDKs that return a key → value map keep reporting `""`, as `get-feature-flag` does.

#### Scenario: Flag result list reads an empty variant as disabled
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | beta-ui   | true  |
  | legacy-ui | ""    |
- **WHEN** get all feature flag results is called
- **THEN** the returned feature flag results should include:
  | key       | enabled |
  | beta-ui   | true    |
  | legacy-ui | false   |
- **AND** the returned feature flag result for "legacy-ui" should have variant equal to the JSON value ""
