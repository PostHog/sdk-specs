@private @canonical_behavior @acceptance @feature_flag_cache @both
Feature: Feature Flag Cache
  Acceptance tests for the canonical feature flag cache behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Cache stores flag values and payloads from a successful load
    Given the SDK is initialized with token "test-token"
    When feature flags are loaded with values:
      | key     | value | payload              |
      | beta-ui | true  | {"color":"green"} |
    Then cached feature flags should include:
      | key     | value |
      | beta-ui | true  |
    And cached feature flag payloads should include:
      | key     | payload              |
      | beta-ui | {"color":"green"} |

  Scenario: Cache serves reads without a network request
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then the returned feature flag value should be true
    And no feature flag network request should be sent

  Scenario: Cache is cleared on identity reset when user-scoped flags are invalidated
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When reset is called
    Then cached feature flags should be empty
