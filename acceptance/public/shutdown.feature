@public @canonical_behavior @acceptance @shutdown @both
Feature: Shutdown
  Acceptance tests for the canonical shutdown behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Shutdown flushes queued events and disables future work
    Given the SDK is initialized with token "test-token"
    And the mock server will accept the next ingestion request with status 200
    And the event queue contains events:
      | event | distinct_id |
      | Save  | user-123    |
    When shutdown is called
    Then the mock server should receive event "Save"
    And the event queue should be empty after a successful flush
    And background workers should be stopped
    When capture is called with event "After Shutdown"
    Then no event named "After Shutdown" should be enqueued

  @both
  Scenario: Shutdown is idempotent
    Given the SDK is initialized with token "test-token"
    When shutdown is called
    And shutdown is called again
    Then neither call should throw
    And background workers should remain stopped

  @both
  Scenario: Shutdown honors delivery failures without crashing
    Given the SDK is initialized with token "test-token"
    And the event queue contains events:
      | event | distinct_id |
      | Save  | user-123    |
    And the mock server will fail the next ingestion request with status 503
    When shutdown is called
    Then the call should not throw
    And the SDK should record a delivery warning
