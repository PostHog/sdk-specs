## MODIFIED Requirements

### Requirement: Canonical capture-exception behavior

The SDK SHALL implement the canonical `capture-exception` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

The canonical exception type and message for a standard captured exception SHALL be represented by the primary exception entry at `$exception_list[0].type` and `$exception_list[0].value`. Legacy top-level `$exception_type` and `$exception_message` properties are not required for standard capture paths. SDKs MAY continue to emit them for compatibility, but SDKs and consumers MUST treat `$exception_list` as the source of truth when it is present.

#### Scenario: Capturing a handled exception emits an exception event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception has stack information
- **WHEN** capture exception is called for an exception with type "TypeError" and message "boom"
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event's exception list should have "TypeError" at index 0
- **AND** the enqueued event's primary exception message should be "boom"
- **AND** the enqueued event should include exception stack information

#### Scenario: Exception capture includes caller properties (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture exception is called with properties:
  | property | value      |
  | handled  | true       |
  | area     | checkout   |
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event properties should include:
  | property | value    |
  | handled  | true     |
  | area     | checkout |

#### Scenario: Exception capture normalizes non-standard thrown values (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture exception is called with a non-standard thrown value
- **THEN** the call should not throw
- **AND** one event named "$exception" should be enqueued
- **AND** the enqueued event should include a normalized exception message

## ADDED Requirements

### Requirement: Server manual exception delivery

For a server SDK exposing manual exception capture, reporting a valid native handled exception with an explicit distinct ID SHALL participate in the SDK's normal capture pipeline. After a public flush completes successfully against a healthy receiver, the receiver SHALL have exactly one corresponding `$exception` event.

The event SHALL retain the supplied distinct ID. Its primary `$exception_list[0]` entry SHALL contain the native exception type and message, `mechanism.handled` equal to the JSON boolean `true`, and a nonempty `stacktrace.frames` array when the native fixture has a stack. Supplied scalar and nested JSON properties SHALL contribute to the payload under the existing capture serialization contract. Properties MAY be omitted without preventing exception delivery.

#### Scenario: Server exception capture delivers a native handled exception with caller properties
- **GIVEN** an isolated SDK instance
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** capture exception is called with JSON arguments:
  ```json
  {"error":{"type":"TypeError","message":"boom"},"distinct_id":"exception-user","properties":{"area":"checkout","retryable":false,"attempt":0,"context":{"operation":"charge","codes":[1,2],"success":false}}}
  ```
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the first request should contain exactly 1 parsed events
- **AND** the first received event field "event" should equal "$exception"
- **AND** the first received event field "distinct_id" should equal "exception-user"
- **AND** the first received event's primary exception should have type "TypeError" and message "boom"
- **AND** the first received event's primary exception should be handled
- **AND** the first received event's primary exception should have stack frames
- **AND** the first received event property "area" should equal "checkout"
- **AND** the first received event property "retryable" should equal JSON false
- **AND** the first received event property "attempt" should equal JSON 0
- **AND** the first received event property "context" should equal JSON {"operation":"charge","codes":[1,2],"success":false}

#### Scenario: Server exception capture delivers a native handled exception without caller properties
- **GIVEN** an isolated SDK instance
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** capture exception is called with JSON arguments:
  ```json
  {"error":{"type":"TypeError","message":"boom without properties"},"distinct_id":"exception-user-no-properties"}
  ```
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the first request should contain exactly 1 parsed events
- **AND** the first received event field "event" should equal "$exception"
- **AND** the first received event field "distinct_id" should equal "exception-user-no-properties"
- **AND** the first received event's primary exception should have type "TypeError" and message "boom without properties"
- **AND** the first received event's primary exception should be handled
- **AND** the first received event's primary exception should have stack frames
