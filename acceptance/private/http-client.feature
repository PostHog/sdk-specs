@private @canonical_behavior @acceptance @http_client @both
Feature: HTTP Client
  Acceptance tests for the canonical http client behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: HTTP client sends ingestion requests with authentication and JSON payload
    Given the SDK is initialized with token "test-token" and host "https://mock.posthog.test"
    And the event queue contains events:
      | event | distinct_id |
      | Save  | user-123    |
    When flush is called
    Then the mock server should receive a request to an ingestion endpoint
    And the request should include token "test-token"
    And the request body should contain event "Save"

  Scenario: HTTP client treats successful status codes as delivered
    Given the SDK is initialized with token "test-token"
    And the mock server will accept the next ingestion request with status 200
    And the event queue contains events:
      | event | distinct_id |
      | Save  | user-123    |
    When flush is called
    Then the event queue should be empty after a successful flush

  Scenario: HTTP client reports retryable failures without throwing to capture callers
    Given the SDK is initialized with token "test-token"
    And the mock server will fail the next ingestion request with status 503
    When capture is called with event "Retry Me"
    And flush is called
    Then the call should not throw
    And the event named "Retry Me" should remain queued for retry
