@private @canonical_behavior @acceptance @feature_flag_called_tracker @both
Feature: Feature Flag Called Tracker
  Acceptance tests for the canonical feature flag called tracker behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Tracker emits the first flag-called event for a value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should include:
      | property     | value   |
      | $feature_flag | beta-ui |
      | $feature_flag_response | true |

  Scenario: Tracker suppresses duplicate events for the same flag value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And get feature flag "beta-ui" is called again
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

  Scenario: Tracker emits again when the flag value changes
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And cached feature flag "beta-ui" changes to "false"
    And get feature flag "beta-ui" is called
    Then two "$feature_flag_called" events should be enqueued for flag "beta-ui"
