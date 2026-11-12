## ADDED Requirements

### Requirement: Empty variant reads as disabled

A flag whose value is the empty string `""` SHALL read as disabled. The SDK SHALL return a result with `enabled: false` and `variant: ""`, and `is-feature-enabled` SHALL return `false` for it, whether or not the caller supplies a default.

Known gap: posthog-js core and react-native still return `enabled: true` from `getFeatureFlagResult` for `""`, because `getEnabledFromValue` reads any string as enabled, while their `isFeatureEnabled` returns `false`. A follow-up should make `getFeatureFlagResult` match.

#### Scenario: Empty variant flag result is disabled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | legacy-ui | ""    |
- **WHEN** get feature flag result "legacy-ui" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | legacy-ui |
  | enabled | false     |
- **AND** its variant should equal the JSON value ""
- **WHEN** is feature enabled "legacy-ui" is called
- **THEN** the returned enabled state should be false

## Narrative alignment

When syncing this delta, in both the client-side and server-side flows, replace "Multivariate flag → `enabled = true`, `variant = '<variant>'`" with "Multivariate flag with a non-empty variant → `enabled = true`, `variant = '<variant>'`" and add "Empty variant `''` → `enabled = false`, `variant = ''`".

Also sync `is-feature-enabled`: in its server-side flow replace "variant string → `true`" with "non-empty variant string → `true`", matching its client-side flow. No `is-feature-enabled` requirement changes.
