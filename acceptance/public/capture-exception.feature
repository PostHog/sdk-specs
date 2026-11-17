@public @canonical_behavior @acceptance @capture_exception
Feature: Capture Exception
  Acceptance tests for the canonical capture exception behavior across PostHog SDKs.

  Rule: Server manual exception capture

    Background:
      Given an isolated SDK instance
      And the SDK is initialized with token "test-token" and flush threshold 20

    @sdk:server
    Scenario: Server exception capture delivers a native handled exception with caller properties
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"boom"},"distinct_id":"exception-user","properties":{"handled":true,"area":"checkout","retryable":false,"attempt":0,"context":{"operation":"charge","codes":[1,2],"success":false}}}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "exception-user"
      And the first received event's primary exception should have type "TypeError" and message "boom"
      And the first received event's primary exception should be handled
      And the first received event's primary exception should have stack frames
      And the first received event's exception list should contain these types in order:
        | type      |
        | TypeError |
      And the first received event's exception at index 0 mechanism should include JSON {"type":"generic","handled":true,"synthetic":false,"exception_id":0}
      And the first received event property "$exception_level" should equal "error"
      And the first received event property "$exception_source" should be absent
      And the first received event property "handled" should equal JSON true
      And the first received event property "area" should equal "checkout"
      And the first received event property "retryable" should equal JSON false
      And the first received event property "attempt" should equal JSON 0
      And the first received event property "context" should equal JSON {"operation":"charge","codes":[1,2],"success":false}

    @sdk:server
    Scenario: Server exception capture delivers a native handled exception without caller properties
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"boom without properties"},"distinct_id":"exception-user-no-properties"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "exception-user-no-properties"
      And the first received event's primary exception should have type "TypeError" and message "boom without properties"
      And the first received event's primary exception should be handled
      And the first received event's primary exception should have stack frames

    @sdk:server @case:acceptance:server:capture-exception:normalized:<case_id>
    Scenario Outline: Server exception capture normalizes non-standard thrown values
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"value":<value>},"distinct_id":"normalized-user"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "normalized-user"
      And the first received event's primary exception message should contain "<message>"
      And the first received event's primary exception should be handled
      And the first received event's exception at index 0 mechanism should include JSON {"type":"generic","synthetic":true}

      Examples:
        | case_id | value                        | message        |
        | string  | "thrown string"              | thrown string  |
        | zero    | 0                            | 0              |
        | false   | false                        | false          |
        | object  | {"message":"object message"} | object message |

    @sdk:server
    Scenario: Server exception capture preserves existing crash-first stack frames in entry-first order
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"original stack","stack":"TypeError: original stack\n    at boom (/exception-fixture.js:40:2)\n    at handler (/exception-fixture.js:20:2)\n    at main (/exception-fixture.js:10:2)"},"distinct_id":"stack-user"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "stack-user"
      And the first received event's primary exception should have type "TypeError" and message "original stack"
      And the first received event's primary exception frames should contain these functions in order:
        | function |
        | main     |
        | handler  |
        | boom     |
      And the first received event's exception at index 0 mechanism should include JSON {"handled":true,"synthetic":false}

    @sdk:server
    Scenario: Server exception capture orders a wrapper before its root cause
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"wrapper","cause":{"type":"Error","message":"root cause"}},"distinct_id":"cause-user"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "cause-user"
      And the first received event's primary exception should have type "TypeError" and message "wrapper"
      And the first received event's exception list should contain these types in order:
        | type      |
        | TypeError |
        | Error     |
      And the first received event's exception list should have valid tree identifiers
      And the first received event's exception at index 0 mechanism should include JSON {"exception_id":0,"handled":true}
      And the first received event's exception at index 1 mechanism should include JSON {"type":"chained","source":"cause","parent_id":0}
      And the first received event's exception at index 1 should have message "root cause"
      And the first received event's exception at index 1 mechanism should omit "handled"

    @sdk:server
    Scenario: Server exception capture attaches aggregate members to their parent
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"AggregateError","message":"group","errors":[{"type":"TypeError","message":"first member"},{"type":"RangeError","message":"second member"}]},"distinct_id":"aggregate-user"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "aggregate-user"
      And the first received event's primary exception should have type "AggregateError" and message "group"
      And the first received event's exception list should contain these types in order:
        | type           |
        | AggregateError |
        | TypeError      |
        | RangeError     |
      And the first received event's exception list should have valid tree identifiers
      And the first received event's exception at index 1 mechanism should include JSON {"type":"chained","source":"member","parent_id":0}
      And the first received event's exception at index 2 mechanism should include JSON {"type":"chained","source":"member","parent_id":0}
      And the first received event's exception at index 1 should have message "first member"
      And the first received event's exception at index 2 should have message "second member"
      And the first received event's exception at index 1 mechanism should omit "handled"
      And the first received event's exception at index 2 mechanism should omit "handled"

    @sdk:server @requires:null_property_omission
    Scenario: Server exception capture drops null-valued custom object properties on the wire
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"null properties"},"distinct_id":"null-user","properties":{"test":null,"nested":{"drop":null},"items":["1",null,{"drop":null}]}}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "null-user"
      And the first received event's primary exception should have type "TypeError" and message "null properties"
      And the first received event property "test" should be absent
      And the first received event property "nested" should equal JSON {}
      And the first received event property "items" should equal JSON ["1",null,{}]

    @sdk:server
    Scenario: Server manual capture does not trust reserved caller exception metadata
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"type":"TypeError","message":"canonical metadata"},"distinct_id":"metadata-user","properties":{"$exception_list":[{"type":"ForgedError","value":"forged"}],"$exception_level":"fatal","$exception_source":"forged.integration","area":"checkout"}}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "metadata-user"
      And the first received event's primary exception should have type "TypeError" and message "canonical metadata"
      And the first received event property "$exception_level" should equal "error"
      And the first received event property "$exception_source" should be absent
      And the first received event property "area" should equal "checkout"

    @sdk:server
    Scenario: Server exception capture preserves the provenance of an existing error-like object stack
      When capture exception is called with JSON arguments:
        """application/json
        {"error":{"value":{"message":"existing object stack","stack":"Error: existing object stack\n    at originalCrash (/exception-fixture.js:40:2)\n    at originalEntry (/exception-fixture.js:10:2)"}},"distinct_id":"object-stack-user"}
        """
      And pending captures are flushed
      Then exactly 1 capture request should have been received
      And the first request should contain exactly 1 parsed events
      And the first received event field "event" should equal "$exception"
      And the first received event field "distinct_id" should equal "object-stack-user"
      And the first received event's primary exception message should contain "existing object stack"
      And the first received event's primary exception frames should contain these functions in order:
        | function      |
        | originalEntry |
        | originalCrash |
      And the first received event's exception at index 0 mechanism should include JSON {"synthetic":true}

  @client
  Rule: Client manual exception capture

    Background:
      Given an isolated SDK instance
      And the SDK is initialized with token "test-token" and flush threshold 20

    Scenario: Capturing a handled exception emits an exception event
      Given the test exception has stack information
      When capture exception is called for an exception with type "TypeError" and message "boom"
      Then one event named "$exception" should be enqueued
      And the enqueued event's exception list should have "TypeError" at index 0
      And the enqueued event's primary exception message should be "boom"
      And the enqueued event should include exception stack information

    Scenario: Exception capture includes caller properties
      When capture exception is called with properties:
        | property | value    |
        | handled  | true     |
        | area     | checkout |
      Then one event named "$exception" should be enqueued
      And the enqueued event properties should include:
        | property | value    |
        | handled  | true     |
        | area     | checkout |

    @requires:null_property_omission
    Scenario: Exception capture drops null-valued custom properties on the wire
      Given capture has a valid distinct id and no property-changing hooks or filters
      And a valid handled exception
      When capture exception is called for the exception with additional custom properties represented by JSON:
        """json
        {"test":null,"nested":{"drop":null},"items":["1",null,2]}
        """
      And the SDK is flushed
      Then one "$exception" event should be received
      And its custom properties should equal JSON:
        """json
        {"nested":{},"items":["1",null,2]}
        """
      And the event should still include its SDK-generated exception data

    Scenario: Exception capture normalizes non-standard thrown values
      When capture exception is called with a non-standard thrown value
      Then the call should not throw
      And one event named "$exception" should be enqueued
      And the enqueued event should include a normalized exception message

    Scenario: Frames are ordered entry point first, crash site last
      Given the test exception is raised through the call chain "main" -> "handler" -> "boom"
      When capture exception is called for the exception
      Then one event named "$exception" should be enqueued
      And the first frame of the enqueued exception's stacktrace should reference "main"
      And the last frame of the enqueued exception's stacktrace should reference "boom"

    Scenario: Crash-first runtime stacks are reversed before sending
      Given the platform runtime reports exception stacks innermost-first (crash site first)
      When capture exception is called for an exception with stack information
      Then one event named "$exception" should be enqueued
      And the enqueued exception's stacktrace frames should be in the reverse of the runtime order, with the crash site as the last frame

    Scenario: Chained exceptions are listed caught-first, root cause last
      Given the test exception "WrapperError" wraps a cause "RootError"
      When capture exception is called for the caught "WrapperError"
      Then one event named "$exception" should be enqueued
      And the enqueued event's exception list should have "WrapperError" at index 0
      And the enqueued event's exception list should have "RootError" as the last element

  @both
  Rule: Platform-specific chaining and source context

    Background:
      Given an isolated SDK instance
      And the SDK is initialized with token "test-token" and flush threshold 20

    Scenario: Platforms without exception chaining send a single-element list
      Given the platform has no exception cause/chain concept
      When capture exception is called for an exception
      Then one event named "$exception" should be enqueued
      And the enqueued event's exception list should contain exactly one exception

    Scenario: Context arrays are in ascending file order
      Given the SDK attaches source context with a 5-line window
      When capture exception is called for an exception raised at line 40 of a source file
      Then one event named "$exception" should be enqueued
      And the crash-site frame's "context_line" should be the source line 40
      And the crash-site frame's "pre_context" should be source lines 35 through 39 in ascending order
      And the crash-site frame's "post_context" should be source lines 41 through 45 in ascending order

    Scenario: Frames without source context are valid
      Given the SDK does not capture source context
      When capture exception is called for an exception with stack information
      Then one event named "$exception" should be enqueued
      And the enqueued exception's stacktrace frames should omit "context_line", "pre_context", and "post_context"
