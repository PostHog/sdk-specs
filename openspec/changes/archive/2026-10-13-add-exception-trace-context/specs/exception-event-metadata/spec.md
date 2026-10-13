## ADDED Requirements

### Requirement: Active trace context on exception events

When a valid OpenTelemetry span is active in the ambient context at capture time, an SDK-owned exception capture path SHALL set `$trace_id` to the span's trace ID and `$span_id` to the span's span ID on the `$exception` event. `$trace_id` SHALL be 32 lowercase hexadecimal characters and `$span_id` SHALL be 16 lowercase hexadecimal characters, with no separators and no version prefix. A span context is valid only when neither ID is all zeros.

The SDK SHALL omit both properties when no span is active, when the active span context is invalid, or when the platform has no OpenTelemetry API available. The SDK SHALL NOT infer trace context from request headers or from any source other than the active span. A value that the caller supplies for either property SHALL be preserved and SHALL NOT be replaced by the active span. If reading the trace context fails, the SDK SHALL still enqueue the exception event without the properties and SHALL NOT throw to application code.

`$trace_id` and `$span_id` are producer-supplied join keys. Cymbal preserves them and does not derive them.

#### Scenario: Exception inside an active span carries trace and span IDs (@server)
- **GIVEN** an OpenTelemetry span with trace ID `4bf92f3577b34da6a3ce929d0e0e4736` and span ID `00f067aa0ba902b7` is active
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event property `$trace_id` should equal `4bf92f3577b34da6a3ce929d0e0e4736`
- **AND** the enqueued event property `$span_id` should equal `00f067aa0ba902b7`

#### Scenario: Exception outside any span omits both properties (@server)
- **GIVEN** no OpenTelemetry span is active
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`

#### Scenario: Invalid span context omits both properties (@server)
- **GIVEN** the active span context has an all-zero trace ID and an all-zero span ID
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`

#### Scenario: Caller-supplied values are preserved (@server)
- **GIVEN** an OpenTelemetry span is active
- **AND** the caller supplies `$trace_id` equal to `custom-trace` and `$span_id` equal to `custom-span`
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event property `$trace_id` should equal `custom-trace`
- **AND** the enqueued event property `$span_id` should equal `custom-span`

#### Scenario: Failure to read trace context does not drop the event (@server)
- **GIVEN** reading the active span context raises an error
- **WHEN** the SDK captures an exception
- **THEN** one event named `$exception` should be enqueued
- **AND** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`
- **AND** event creation should not throw
