@private @canonical_behavior @acceptance @feature_flag_called_tracker @both
Feature: Feature Flag Called Tracker
  Acceptance tests for the canonical feature flag called tracker behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
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

  @both
  Scenario: Tracker suppresses duplicate events for the same flag value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And get feature flag "beta-ui" is called again
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

  @both
  Scenario: Tracker emits again when the flag value changes
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And cached feature flag "beta-ui" changes to "false"
    And get feature flag "beta-ui" is called
    Then two "$feature_flag_called" events should be enqueued for flag "beta-ui"

  @server
  Scenario: Tracker suppresses duplicates for the same server group context
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include a group flag "company-beta" returning true for group type "company"
    When get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
      | team    | team-1      |
    And get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | team    | team-1      |
      | company | company-123 |
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "company-beta"

  @server
  Scenario: Tracker emits again when server group context changes
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include a group flag "company-beta" returning true for group type "company"
    When get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
    And get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-456 |
    Then two "$feature_flag_called" events should be enqueued for flag "company-beta"

  @client
  Scenario: Tracker clears on identity reset
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And reset is called
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    And get feature flag "beta-ui" is called
    Then two "$feature_flag_called" events should be enqueued for flag "beta-ui"

  @both
  Scenario: Tracker clears on SDK shutdown
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And shutdown is called
    Then feature flag called tracker state should be empty
