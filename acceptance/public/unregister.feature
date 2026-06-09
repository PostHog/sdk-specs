@public @canonical_behavior @acceptance @unregister @client
Feature: Unregister
  Acceptance tests for the canonical unregister behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Unregister removes a super property from future events
    Given the SDK is initialized with token "test-token"
    And registered properties are:
      | property | value |
      | plan     | pro   |
      | region   | eu    |
    When unregister is called for property "plan"
    And capture is called with event "Viewed Dashboard"
    Then the enqueued event should not include property "plan"
    And the enqueued event property "region" should equal "eu"

  Scenario: Unregister persists removal
    Given the SDK is initialized with token "test-token"
    And registered property "plan" is "pro"
    When unregister is called for property "plan"
    And the SDK is restarted
    And capture is called with event "Loaded"
    Then the enqueued event should not include property "plan"

  Scenario: Unregister missing property is a no-op
    Given the SDK is initialized with token "test-token"
    When unregister is called for property "missing"
    Then the call should not throw
    And registered properties should remain unchanged
