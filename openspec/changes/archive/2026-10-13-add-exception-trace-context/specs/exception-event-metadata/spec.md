## ADDED Requirements

### Requirement: Active trace context on exception events

This requirement applies to server SDKs. When a valid span from the ambient OpenTelemetry API is active at capture time, an SDK-owned exception capture path SHALL add the span's trace ID as `$trace_id` and span ID as `$span_id` to the `$exception` event, subject to the SDK's property precedence rules for caller-supplied values. SDK-derived `$trace_id` SHALL be exactly 32 lowercase hexadecimal characters and SDK-derived `$span_id` SHALL be exactly 16, with no separators and no version prefix. Leading zeros SHALL be kept. A span context is valid only when neither ID is all zeros. The SDK SHALL derive the properties whether or not the span is sampled for export, because the IDs still identify the work that failed. An SDK MAY instead read a platform-native ambient tracing API used by OpenTelemetry (for example .NET `System.Diagnostics.Activity`).

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

The SDK SHALL NOT derive `$trace_id` or `$span_id` when no span is active, when the active span context is invalid, or when neither an OpenTelemetry API nor a permitted native tracing API is available. This rule does not remove caller-supplied properties. The SDK SHALL NOT take OpenTelemetry as a required dependency for this behavior: it SHALL look the API up only when the application already provides it. The SDK SHALL NOT infer trace context from request headers or from any source other than the active span. If reading the trace context fails, the SDK SHALL still enqueue the exception event without SDK-derived trace properties and SHALL NOT throw to application code. Client SDKs, which have no ambient OpenTelemetry API, do not derive these properties.

#### Scenario: Exception outside any span omits both properties (@server)
- **GIVEN** no OpenTelemetry span is active
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`

#### Scenario: Invalid span context omits both properties (@server)
- **GIVEN** the active span context has an all-zero trace ID or an all-zero span ID
- **WHEN** the SDK captures an exception
- **THEN** the enqueued event should omit `$trace_id`
- **AND** the enqueued event should omit `$span_id`

#### Scenario: An application without an ambient tracing API still captures exceptions (@server)
- **GIVEN** the application provides neither an OpenTelemetry API nor a permitted native tracing API
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
