@public @canonical_behavior @acceptance @get_feature_flags_and_payloads @both
Feature: Get Feature Flags And Payloads
  Acceptance tests for the canonical get feature flags and payloads behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Bulk getter returns flags and payloads together
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload               |
      | beta-ui  | true  | {"color":"green"} |
      | checkout | blue  | {"copy":"new"}    |
    When get feature flags and payloads is called
    Then the returned feature flag values should be:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
    And the returned feature flag payloads should be:
      | key      | payload             |
      | beta-ui  | {"color":"green"} |
      | checkout | {"copy":"new"}    |

  @both
  Scenario: Bulk values and payloads are empty when no flags are known
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When get feature flags and payloads is called
    Then the returned feature flag values should be empty
    And the returned feature flag payloads should be empty
