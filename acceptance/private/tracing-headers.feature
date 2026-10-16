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
    When the application sends an HTTP request to "https://api.example.com/v1/work"
    Then the outgoing request should include header "X-POSTHOG-DISTINCT-ID" with value "user-123"
    And the outgoing request should include header "X-POSTHOG-SESSION-ID" with value "session-123"

  @client
  Scenario: Client does not inject tracing headers into unlisted hosts
    Given the SDK is initialized with token "test-token" and tracing headers are enabled for host "api.example.com"
    And the current distinct id is "user-123"
    And the current session id is "session-123"
    When the application sends an HTTP request to "https://other.example/v1/work"
    Then the outgoing request should not include header "X-POSTHOG-DISTINCT-ID"
    And the outgoing request should not include header "X-POSTHOG-SESSION-ID"

  @server
  Scenario: Server middleware applies tracing headers to request-scoped capture context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                 | value       |
      | X-POSTHOG-DISTINCT-ID  | user-123    |
      | X-POSTHOG-SESSION-ID   | session-123 |
    And capture is called with event "Backend Work" inside that request context
    Then one event named "Backend Work" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property    | value       |
      | $session_id | session-123 |

  @server
  Scenario: Explicit capture values override server tracing context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                 | value          |
      | X-POSTHOG-DISTINCT-ID  | header-user    |
      | X-POSTHOG-SESSION-ID   | header-session |
    And capture is called with distinct id "explicit-user", event "Backend Work", and properties:
      | property    | value            |
      | $session_id | explicit-session |
    Then one event named "Backend Work" should be enqueued
    And the enqueued event distinct id should be "explicit-user"
    And the enqueued event properties should include:
      | property    | value            |
      | $session_id | explicit-session |

  @server
  Scenario: Server capture without explicit or context distinct id is personless
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                | value       |
      | X-POSTHOG-SESSION-ID  | session-123 |
    And capture is called with event "Backend Work" inside that request context
    Then one event named "Backend Work" should be enqueued
    And the enqueued event should include a generated distinct id
    And the enqueued event properties should include:
      | property                | value       |
      | $session_id             | session-123 |
      | $process_person_profile | false       |

  @server
  Scenario: Server feature flag evaluation without explicit or context distinct id is empty
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with headers:
      | header                | value       |
      | X-POSTHOG-SESSION-ID  | session-123 |
    And evaluate feature flags is called without a distinct id inside that request context
    Then the returned feature flag evaluation should be empty
    And no feature flag request should be sent
    And no event named "$feature_flag_called" should be enqueued

  @server
  Scenario: Server sanitizes tracing header values before storing context
    Given the SDK is initialized with token "test-token"
    And server request context middleware is installed
    When a server request is handled with tracing headers containing surrounding whitespace and control characters
    And capture is called with event "Sanitized Work" inside that request context
    Then one event named "Sanitized Work" should be enqueued
    And the enqueued event should use sanitized tracing context values
    And empty or invalid tracing header values should be omitted

  @server
  Scenario: Request span started before middleware receives PostHog context
    Given the documented server tracing integration is installed
    And an application-owned recording request span is active before header extraction
    When the middleware extracts distinct id "user-one" and session id "session-one"
    And the request span is exported
    Then its span attributes should include:
      | attribute         | value       |
      | posthogDistinctId | user-one    |
      | sessionId         | session-one |

  @server
  Scenario: Child span keeps context after request cleanup
    Given the documented child span integration is installed
    And a child span starts inside request context with session id "session-one"
    When that request context ends
    And another request uses session id "session-two"
    And the original child span is exported
    Then its span attribute "sessionId" should be "session-one"

  @server
  Scenario Outline: Explicit span attributes override request context
    Given the documented server tracing integration is installed
    And an active recording request span has attribute "<attribute>" with value "explicit-value"
    When the middleware extracts distinct id "header-user" and session id "header-session"
    And the request span is exported
    Then its span attribute "<attribute>" should be "explicit-value"

    Examples:
      | attribute         |
      | posthogDistinctId |
      | sessionId         |

  @server
  Scenario: Missing request IDs do not create span identity
    Given the documented server tracing integration is installed
    When a request without valid PostHog identity headers is handled
    And its recording request span is exported
    Then the span should have no "sessionId" or "posthogDistinctId" attributes

  @server
  Scenario: Concurrent child spans use only their own request context
    Given the documented child span integration is installed
    When two concurrent requests with different session ids each start and export a child span
    Then each exported child span should carry only its own request session id

  @server
  Scenario: Detached work does not use ended request context
    Given the documented child span integration is installed
    And detached async work inherited a request execution context
    And that request scope has ended
    When the work starts and exports a span without establishing a new PostHog context
    Then the span should have no IDs from the ended request scope

  @server
  Scenario Outline: Optional tracing enrichment preserves request handling
    Given server request context middleware is installed
    And <condition>
    When an application request completes or raises its normal error
    Then its normal result or error should be preserved
    And existing analytics context behavior should be preserved
    And PostHog should not create a replacement span or change application tracing setup

    Examples:
      | condition                                  |
      | no tracing runtime is installed            |
      | the tracing context lookup fails           |
      | application sampling drops the request span |
