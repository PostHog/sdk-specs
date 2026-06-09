@private @canonical_behavior @acceptance @retry_queue @both
Feature: Retry Queue
  Acceptance tests for the canonical retry queue behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Retry queue keeps events after transient failure
    Given the SDK is initialized with token "test-token"
    And the mock server will fail the next ingestion request with status 503
    When capture is called with event "Retry Me"
    And flush is called
    Then the event named "Retry Me" should remain queued for retry

  Scenario: Retry queue delivers events after a later success
    Given the SDK is initialized with token "test-token"
    And the event named "Retry Me" is queued for retry
    And the mock server will accept the next ingestion request with status 200
    When retry queue processing runs
    Then the mock server should receive event "Retry Me"
    And the event named "Retry Me" should be removed from the retry queue

  Scenario: Retry queue drops or bounds events when capacity is exceeded
    Given the SDK is initialized with token "test-token" and retry queue capacity is 2
    When three events are added to the retry queue
    Then the retry queue size should be 2
    And the SDK should record a queue capacity warning
