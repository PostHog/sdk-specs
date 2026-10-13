## ADDED Requirements

### Requirement: Active trace context on exception events

This requirement applies to server SDKs. When a valid span from the ambient OpenTelemetry API is active at capture time, an SDK-owned exception capture path SHALL set `$trace_id` to the span's trace ID and `$span_id` to the span's span ID on the `$exception` event. `$trace_id` SHALL be exactly 32 lowercase hexadecimal characters and `$span_id` SHALL be exactly 16, with no separators and no version prefix. Leading zeros SHALL be kept. A span context is valid only when neither ID is all zeros. The SDK SHALL set the properties whether or not the span is sampled for export, because the IDs still identify the work that failed. A platform whose ambient tracing API is built on OpenTelemetry but has another name (for example .NET `System.Diagnostics.Activity`) MAY read that API instead.

#### Scenario: Exception inside an active span carries trace and span IDs (@server)
- **GIVEN** an OpenTelemetry span with trace ID `4bf92f3577b34da6a3ce929d0e0e4736` and span ID `00f067aa0ba902b7` is active
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event property `$trace_id` should equal `4bf92f3577b34da6a3ce929d0e0e4736`
- **AND** the enqueued event property `$span_id` should equal `00f067aa0ba902b7`

#### Scenario: Leading zeros are kept (@server)
- **GIVEN** an OpenTelemetry span with trace ID `00000000000000000000000000000001` and span ID `0000000000000002` is active
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event property `$trace_id` should equal `00000000000000000000000000000001`
- **AND** the enqueued event property `$span_id` should equal `0000000000000002`

#### Scenario: A span that is not sampled still sets the IDs (@server)
- **GIVEN** an active OpenTelemetry span whose trace flags mark it as not sampled
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event should contain `$trace_id` and `$span_id` equal to the span's IDs

### Requirement: Absent or unreadable trace context on exception events

The SDK SHALL omit both `$trace_id` and `$span_id` when no span is active, when the active span context is invalid, or when the application does not provide an OpenTelemetry API. The SDK SHALL NOT take OpenTelemetry as a required dependency for this behavior: it SHALL look the API up only when the application already provides it. The SDK SHALL NOT infer trace context from request headers or from any source other than the active span. If reading the trace context fails, the SDK SHALL still enqueue the exception event without the properties and SHALL NOT throw to application code. Client SDKs, which have no ambient OpenTelemetry API, omit both properties.

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

#### Scenario: An application without OpenTelemetry still captures exceptions (@server)
- **GIVEN** the application does not provide an OpenTelemetry API
- **WHEN** the SDK captures an exception
- **THEN** one event named `$exception` should be enqueued
- **AND** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`

#### Scenario: Failure to read trace context does not drop the event (@server)
- **GIVEN** reading the active span context raises an error
- **WHEN** the SDK captures an exception
- **THEN** one event named `$exception` should be enqueued
- **AND** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`
- **AND** event creation should not throw
