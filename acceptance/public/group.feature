@public @canonical_behavior @acceptance @group @client
Feature: Group
  Acceptance tests for the canonical group behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Group stores group context for future events
    Given the SDK is initialized with token "test-token"
    When group is called with type "company" and key "company-123"
    Then registered groups should include:
      | group_type | group_key   |
      | company    | company-123 |
    When capture is called with event "Viewed Dashboard"
    Then the enqueued event property "$groups" should include group "company" with key "company-123"

  Scenario: Group can include group properties
    Given the SDK is initialized with token "test-token"
    When group is called with type "company", key "company-123", and properties:
      | property | value |
      | plan     | pro   |
    Then one event named "$groupidentify" should be enqueued
    And the enqueued event property "plan" should equal "pro"
    And future events should include group "company" with key "company-123"

  Scenario: Group rejects missing type or key
    Given the SDK is initialized with token "test-token"
    When group is called without a group key
    Then group context should not change
    And the SDK should record a validation warning
