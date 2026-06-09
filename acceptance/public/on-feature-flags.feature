@public @canonical_behavior @acceptance @on_feature_flags @client
Feature: On Feature Flags
  Acceptance tests for the canonical on feature flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Listener is invoked when feature flags are loaded
    Given the SDK is initialized with token "test-token"
    And a feature flag listener is registered
    When feature flags are loaded with values:
      | key     | value |
      | beta-ui | true  |
    Then the feature flag listener should be invoked with flags:
      | key     | value |
      | beta-ui | true  |

  Scenario: Listener registered after flags are ready is invoked with current values
    Given the SDK is initialized with token "test-token"
    And feature flags are already loaded with values:
      | key     | value |
      | beta-ui | true  |
    When a feature flag listener is registered
    Then the feature flag listener should be invoked with flags:
      | key     | value |
      | beta-ui | true  |

  Scenario: Listener can be unsubscribed
    Given the SDK is initialized with token "test-token"
    And a feature flag listener is registered
    When the feature flag listener is unsubscribed
    And feature flags are loaded with values:
      | key     | value |
      | beta-ui | true  |
    Then the feature flag listener should not be invoked again
