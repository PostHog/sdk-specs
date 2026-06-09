@public @canonical_behavior @acceptance @is_feature_enabled @both
Feature: Is Feature Enabled
  Acceptance tests for the canonical is feature enabled behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario Outline: Enabled check maps flag values to booleans
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value        |
      | feature | <flag_value> |
    When is feature enabled "feature" is called
    Then the returned enabled value should be <enabled>

    Examples:
      | flag_value | enabled |
      | true       | true    |
      | false      | false   |
      | variant-a  | true    |

  @both
  Scenario: Enabled check returns false for missing flags
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When is feature enabled "missing" is called
    Then the returned enabled value should be false

  @both
  Scenario: Enabled check can suppress tracking
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | feature | true  |
    When is feature enabled "feature" is called with tracking disabled
    Then the returned enabled value should be true
    And no event named "$feature_flag_called" should be enqueued
