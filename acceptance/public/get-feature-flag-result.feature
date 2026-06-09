@public @canonical_behavior @acceptance @get_feature_flag_result @both
Feature: Get Feature Flag Result
  Acceptance tests for the canonical get feature flag result behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Structured result includes key enabled variant and payload
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload              |
      | checkout | blue  | {"copy":"new"}    |
    When get feature flag result "checkout" is called
    Then the returned feature flag result should include:
      | field   | value           |
      | key     | checkout        |
      | enabled | true            |
      | variant | blue            |
      | payload | {"copy":"new"} |

  @both
  Scenario: Boolean false flag result is disabled
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | false |
    When get feature flag result "beta-ui" is called
    Then the returned feature flag result should include:
      | field   | value   |
      | key     | beta-ui |
      | enabled | false   |
    And the returned feature flag result should not include a variant

  @both
  Scenario: Unknown flag returns no structured result
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When get feature flag result "missing-flag" is called
    Then no feature flag result should be returned
