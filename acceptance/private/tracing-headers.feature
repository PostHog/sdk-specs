@private @canonical_behavior @acceptance @tracing_headers @both
Feature: Tracing headers
  Acceptance tests for canonical PostHog tracing header behavior across client and server SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client injects tracing headers into allowlisted hosts
    Given the SDK is initialized with token "test-token" and tracing headers are enabled for host "api.example.com"
    And the current distinct id is "user-123"
    And the current session id is "session-123"
    And the current window id is "window-123"
    When the application sends an HTTP request to "https://api.example.com/v1/work"
    Then the outgoing request should include header "X-POSTHOG-DISTINCT-ID" with value "user-123"
    And the outgoing request should include header "X-POSTHOG-SESSION-ID" with value "session-123"
    And web SDKs should include header "X-POSTHOG-WINDOW-ID" with value "window-123"
    And SDKs without a window concept should omit header "X-POSTHOG-WINDOW-ID"

  @client
  Scenario: Client does not inject tracing headers into unlisted hosts
    Given the SDK is initialized with token "test-token" and tracing headers are enabled for host "api.example.com"
    And the current distinct id is "user-123"
    And the current session id is "session-123"
    When the application sends an HTTP request to "https://other.example/v1/work"
    Then the outgoing request should not include header "X-POSTHOG-DISTINCT-ID"
    And the outgoing request should not include header "X-POSTHOG-SESSION-ID"
    And the outgoing request should not include header "X-POSTHOG-WINDOW-ID"

  @server
  Scenario: Server middleware applies tracing headers to request-scoped capture context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                 | value       |
      | X-POSTHOG-DISTINCT-ID  | user-123    |
      | X-POSTHOG-SESSION-ID   | session-123 |
      | X-POSTHOG-WINDOW-ID    | window-123  |
    And capture is called with event "Backend Work" inside that request context
    Then one event named "Backend Work" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property    | value       |
      | $session_id | session-123 |
      | $window_id  | window-123  |

  @server
  Scenario: Explicit capture values override server tracing context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                 | value          |
      | X-POSTHOG-DISTINCT-ID  | header-user    |
      | X-POSTHOG-SESSION-ID   | header-session |
      | X-POSTHOG-WINDOW-ID    | header-window  |
    And capture is called with distinct id "explicit-user", event "Backend Work", and properties:
      | property    | value            |
      | $session_id | explicit-session |
      | $window_id  | explicit-window  |
    Then one event named "Backend Work" should be enqueued
    And the enqueued event distinct id should be "explicit-user"
    And the enqueued event properties should include:
      | property    | value            |
      | $session_id | explicit-session |
      | $window_id  | explicit-window  |

  @server
  Scenario: Server sanitizes tracing header values before storing context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with tracing headers containing surrounding whitespace and control characters
    And capture is called with event "Sanitized Work" inside that request context
    Then one event named "Sanitized Work" should be enqueued
    And the enqueued event should use sanitized tracing context values
    And empty or invalid tracing header values should be omitted
