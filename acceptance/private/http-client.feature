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

  Scenario: Flags request retries one transient transport failure by default
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    And the next feature flag request will fail with a transient transport timeout before any HTTP response
    And the following feature flag request will return feature flags:
      | key     | value |
      | beta-ui | true  |
    When feature flags are loaded from the remote flags endpoint
    Then exactly 2 feature flag requests should be sent
    And the first retry should not be sent before 300ms have elapsed
    And cached feature flags should include:
      | key     | value |
      | beta-ui | true  |

  Scenario: Flags request does not retry HTTP status errors
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    And the next feature flag request will fail with HTTP status 503
    When feature flags are loaded from the remote flags endpoint
    Then exactly 1 feature flag request should be sent
    And cached feature flags should still include:
      | key     | value |
      | beta-ui | true  |
    And the call should not throw in normal client reload operation

  Scenario: Zero configured flag retries disables retry
    Given the SDK is initialized with token "test-token" and feature flag request max retries 0
    And the next feature flag request will fail with a transient transport timeout before any HTTP response
    When feature flags are loaded from the remote flags endpoint
    Then exactly 1 feature flag request should be sent

  Scenario: Configured flag retries use 300ms exponential backoff
    Given the SDK is initialized with token "test-token" and feature flag request max retries 2
    And the next 2 feature flag requests will fail with transient transport timeouts before any HTTP response
    And the following feature flag request will return feature flags:
      | key     | value |
      | beta-ui | true  |
    When feature flags are loaded from the remote flags endpoint
    Then exactly 3 feature flag requests should be sent
    And the first retry should not be sent before 300ms have elapsed
    And the second retry should not be sent before 600ms have elapsed after the first retry
    And cached feature flags should include:
      | key     | value |
      | beta-ui | true  |
