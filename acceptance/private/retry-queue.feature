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

  @bounded_durable_queue
  Scenario: Pre-response transport failures exhaust retries without deleting durable records
    Given the SDK is initialized with token "test-token" and the normal retry-count budget permits 2 retries after the initial ingestion attempt
    And the private retry harness configures a backoff maximum of 10 seconds and records scheduled retry delays
    And the next 3 ingestion attempts will fail with a recognized transient transport error before any HTTP response
    When capture is called with event "Keep Me"
    And flush and retry queue processing run until the 3 failed ingestion attempts have occurred
    Then the event named "Keep Me" should remain durably queued
    And at least one retry delay should have been recorded
    And every recorded retry delay should be at most 10 seconds

  @bounded_durable_queue
  Scenario: Retryable HTTP failures exhaust retries without becoming a retention limit
    Given the SDK is initialized with token "test-token" and the normal retry-count budget permits 2 retries after the initial ingestion attempt
    And the next 3 ingestion attempts will return status 503
    When capture is called with event "Retry Later"
    And flush and retry queue processing run until the 3 failed ingestion attempts have occurred
    Then the event named "Retry Later" should remain durably queued
    Given the mock server will accept the next ingestion request with status 200
    And the SDK clock advances beyond the current retry cooldown
    When an independent flush trigger runs
    Then the mock server should receive event "Retry Later"
    And the event named "Retry Later" should be removed from the retry queue

  @connectivity_monitor
  Scenario: Known-offline queues pause attempts and resume after connectivity returns
    Given the SDK is initialized with token "test-token"
    And the SDK network monitor reports that the network is unavailable
    When capture is called with event "Captured Offline"
    And flush and retry queue processing run for one flush interval
    Then the mock server should receive no ingestion request
    And the flush retry budget should not be consumed
    And the event named "Captured Offline" should remain queued
    Given the SDK network monitor reports that the network is available
    And the mock server will accept the next ingestion request with status 200
    When retry queue processing runs
    Then the mock server should receive event "Captured Offline"
    And the event named "Captured Offline" should be removed from the retry queue

  @evicts_existing_entries
  Scenario: Successful flush acknowledges queue identities rather than matching payload values
    Given the SDK is initialized with token "test-token" and retry queue capacity is 3
    And queue entries "initial-1", "initial-2", and "initial-3" contain the same serialized event payload
    And the mock server will delay the next ingestion request until released
    When flush is called
    And queue entries "replacement-1", "replacement-2", and "replacement-3" with the same serialized event payload are added while the flush is in flight
    And capacity eviction replaces queue entries "initial-1", "initial-2", and "initial-3"
    And the delayed ingestion request is released and succeeds
    Then queue entries "replacement-1", "replacement-2", and "replacement-3" should remain queued
    When a subsequent flush succeeds
    Then the mock server should receive the three replacement entries
