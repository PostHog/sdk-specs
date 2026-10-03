## Narrative alignment

When syncing this delta, add posthog-ios to the **Surface variants** list:

- **iOS:** `onFeatureFlags(callback) -> Subscription` with `unsubscribe()`, where the callback
  receives the enabled flag keys, their variants, and `errorsLoading`. Also available from
  Objective-C as `onFeatureFlags:`.

In **Behavior** item 4, group iOS with browser as a payload-carrying surface rather than a
readiness-only one. In item 5, add iOS alongside browser as an SDK that invokes a late-registered
listener once with the current values. Leave the readiness-only description of Android, Flutter, and
Unity unchanged.

In **Concurrency & ordering guarantees**, keep the existing post-commit ordering rule and note that
an SDK with a main/UI thread (posthog-ios) delivers on that thread, after the getters already return
the new values.

## MODIFIED Requirements

### Requirement: Canonical on-feature-flags behavior

The SDK SHALL implement the canonical `on-feature-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Listener is invoked when feature flags are loaded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Listener registered after flags are ready is invoked with current values
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are already loaded with values:
  | key     | value |
  | beta-ui | true  |
- **WHEN** a feature flag listener is registered
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Listener can be unsubscribed
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** the feature flag listener is unsubscribed
- **AND** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should not be invoked again

#### Scenario: Listener is invoked with the last known flags when a load fails
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are already loaded with values:
  | key     | value |
  | beta-ui | true  |
- **AND** a feature flag listener is registered
- **WHEN** a feature flag load fails
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |
- **AND** the feature flag listener should be told that loading flags errored
