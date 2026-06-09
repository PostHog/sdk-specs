@public @canonical_behavior @acceptance @register @client
Feature: Register
  Acceptance tests for the canonical register behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Register adds super properties to future events
    Given the SDK is initialized with token "test-token"
    When register is called with properties:
      | property | value |
      | plan     | pro   |
      | region   | eu    |
    And capture is called with event "Viewed Dashboard"
    Then the enqueued event properties should include:
      | property | value |
      | plan     | pro   |
      | region   | eu    |

  Scenario: Later register calls override existing super properties
    Given the SDK is initialized with token "test-token"
    And registered properties are:
      | property | value |
      | plan     | free  |
    When register is called with properties:
      | property | value |
      | plan     | pro   |
    Then registered property "plan" should equal "pro"

  Scenario: Registered properties persist across SDK initialization
    Given persistent storage contains registered properties:
      | property | value |
      | plan     | pro   |
    When the SDK is initialized with token "test-token"
    And capture is called with event "Loaded"
    Then the enqueued event property "plan" should equal "pro"
