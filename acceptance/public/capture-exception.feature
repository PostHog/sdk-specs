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
      | property | value    |
      | handled  | true     |
      | area     | checkout |
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

  @both
  Scenario: Frames are ordered entry point first, crash site last
    Given the SDK is initialized with token "test-token"
    And the test exception is raised through the call chain "main" -> "handler" -> "boom"
    When capture exception is called for the exception
    Then one event named "$exception" should be enqueued
    And the first frame of the enqueued exception's stacktrace should reference "main"
    And the last frame of the enqueued exception's stacktrace should reference "boom"

  @both
  Scenario: Crash-first runtime stacks are reversed before sending
    Given the SDK is initialized with token "test-token"
    And the platform runtime reports exception stacks innermost-first (crash site first)
    When capture exception is called for an exception with stack information
    Then one event named "$exception" should be enqueued
    And the enqueued exception's stacktrace frames should be in the reverse of the runtime order, with the crash site as the last frame

  @both
  Scenario: Chained exceptions are listed caught-first, root cause last
    Given the SDK is initialized with token "test-token"
    And the test exception "WrapperError" wraps a cause "RootError"
    When capture exception is called for the caught "WrapperError"
    Then one event named "$exception" should be enqueued
    And the enqueued event's exception list should have "WrapperError" at index 0
    And the enqueued event's exception list should have "RootError" as the last element

  @both
  Scenario: Platforms without exception chaining send a single-element list
    Given the SDK is initialized with token "test-token"
    And the platform has no exception cause/chain concept
    When capture exception is called for an exception
    Then one event named "$exception" should be enqueued
    And the enqueued event's exception list should contain exactly one exception

  @both
  Scenario: Context arrays are in ascending file order
    Given the SDK is initialized with token "test-token"
    And the SDK attaches source context with a 5-line window
    When capture exception is called for an exception raised at line 40 of a source file
    Then one event named "$exception" should be enqueued
    And the crash-site frame's "context_line" should be the source line 40
    And the crash-site frame's "pre_context" should be source lines 35 through 39 in ascending order
    And the crash-site frame's "post_context" should be source lines 41 through 45 in ascending order

  @both
  Scenario: Frames without source context are valid
    Given the SDK is initialized with token "test-token"
    And the SDK does not capture source context
    When capture exception is called for an exception with stack information
    Then one event named "$exception" should be enqueued
    And the enqueued exception's stacktrace frames should omit "context_line", "pre_context", and "post_context"
