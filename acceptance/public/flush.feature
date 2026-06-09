@public @canonical_behavior @acceptance @flush @both
Feature: Flush
  Acceptance tests for the canonical flush behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Flush immediately sends queued events
    Given the SDK is initialized with token "test-token"
    And the event queue contains events:
      | event      | distinct_id |
      | First      | user-123    |
      | Second     | user-123    |
    When flush is called
    Then the mock server should receive a batch containing events:
      | event  |
      | First  |
      | Second |
    And the event queue should be empty after a successful flush

  @both
  Scenario: Flush is safe when the queue is empty
    Given the SDK is initialized with token "test-token"
    And the event queue is empty
    When flush is called
    Then the call should not throw
    And no network request should be sent

  @both
  Scenario: Flush keeps events retryable when delivery fails
    Given the SDK is initialized with token "test-token"
    And the event queue contains events:
      | event | distinct_id |
      | Save  | user-123    |
    And the mock server will fail the next ingestion request with status 503
    When flush is called
    Then the call should not throw
    And the event named "Save" should remain queued for retry
