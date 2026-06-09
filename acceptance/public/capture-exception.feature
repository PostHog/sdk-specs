@public @canonical_behavior @acceptance @capture_exception @both
Feature: Capture Exception
  Acceptance tests for the canonical capture exception behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Capturing a handled exception emits an exception event
    Given the SDK is initialized with token "test-token"
    And the test exception has stack information
    When capture exception is called for an exception with type "TypeError" and message "boom"
    Then one event named "$exception" should be enqueued
    And the enqueued event properties should include:
      | property           | value     |
      | $exception_type    | TypeError |
      | $exception_message | boom      |
    And the enqueued event should include exception stack information

  @both
  Scenario: Exception capture includes caller properties
    Given the SDK is initialized with token "test-token"
    When capture exception is called with properties:
      | property | value      |
      | handled  | true       |
      | area     | checkout   |
    Then one event named "$exception" should be enqueued
    And the enqueued event properties should include:
      | property | value    |
      | handled  | true     |
      | area     | checkout |

  @both
  Scenario: Exception capture normalizes non-standard thrown values
    Given the SDK is initialized with token "test-token"
    When capture exception is called with a non-standard thrown value
    Then the call should not throw
    And one event named "$exception" should be enqueued
    And the enqueued event should include a normalized exception message
