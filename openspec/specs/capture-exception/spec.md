# Capture Exception Specification

## Purpose

`capture-exception` records a **handled exception/error event** as PostHog error-tracking data.

It exists for cases where application code catches an error but still wants to report it to PostHog in the same `$exception` format used by the SDKs' error-tracking systems.

## Applicability

`client` — this is a client-side error-reporting API. The audited implementations live in client/mobile SDKs with ambient device/user/session context and local error-coercion helpers.

## Public signatures

### Canonical client signature

```ts
captureException(
  error: unknown,
  properties?: Record<string, JsonValue>,
): void | CaptureResult
```

### Surface variants

- **posthog-js browser:** `captureException(error, additionalProperties?) => CaptureResult | undefined`
- **flutter:** `captureException({ error, stackTrace?, properties? }) => Future<void>`
- **react-native:** `captureException(error, additionalProperties = {}) => void`
- **iOS:**
  - `captureException(_ error: Error, properties?: [String: Any] = nil)`
  - `captureException(_ exception: NSException, properties?: [String: Any] = nil)`
- **Android:** `captureException(throwable: Throwable, properties: Map<String, Any>? = null) => void`
- **Unity:** `CaptureException(Exception exception, Dictionary<string, object> properties = null) => void`

## Behavior

1. **Guard / no-op if unavailable.** Disabled, uninitialized, or opted-out SDK instances do nothing.
2. **Accept a handled exception-like input plus optional event properties.**
3. **Normalize the input into PostHog exception properties.** The SDK converts the supplied error/exception into its error-tracking payload format, typically including exception type/value, handled metadata, stack trace information, and exception-list style structured data.
4. **Mark the exception as handled.** This public manual-capture API represents caught/handled failures, not uncaught crashes.
5. **Merge caller-supplied properties into the `$exception` payload.** The final precedence of generated vs caller-supplied keys is implementation-specific, but both sources contribute to the event payload.
6. **Send a `$exception` event through the normal capture/error-reporting pipeline.** The event is then enriched and delivered using the SDK's usual distinct-id, session, batching, and transport behavior.
7. **Avoid crashing the host app while reporting.** SDK-internal coercion/reporting failures are generally logged or swallowed rather than rethrown.

## State & lifecycle

### State read

- SDK enabled / initialization state
- opt-out state where enforced by the SDK
- current ambient distinct id / anonymous id
- current session state
- error-tracking configuration/state

### State written

- queued `$exception` event payload
- normal capture-pipeline side effects such as queue/batch mutation
- implementation-specific error-tracking bookkeeping (for example debounce timestamps or suppression checks)

### Lifecycle behavior

- Each call produces one handled exception-report attempt.
- This API does not change identity, consent, or feature-flag state.
- Standard batching, retry, flush, and shutdown behavior applies after the exception event is handed to the capture pipeline.

## Error handling

- This API should not throw in normal operation.
- Disabled or unavailable SDKs no-op.
- Invalid or null exception inputs are ignored or logged.
- Exception-coercion failures are typically swallowed/logged so reporting an exception does not itself crash the app.
- Some SDKs may drop the event before capture when local suppression/error-tracking rules say it should not be sent.

## Concurrency & ordering guarantees

- `capture-exception(...)` participates in the same ordering guarantees as ordinary capture/event submission within each SDK.
- Concurrent exception captures are serialized by the SDK's underlying capture/queueing infrastructure.
- No stronger ordering guarantees are provided beyond the SDK's normal batching/queue semantics.

## Interactions

- **`capture`** — manual exception capture ultimately emits a `$exception` event through the standard event pipeline.
- **Error-tracking processors/builders** — these convert raw errors/exceptions into the structured PostHog exception property format.
- **Event batcher / retry queue** — `$exception` events are delivered through the same batching/retry infrastructure as other events.
- **Autocaptured exception systems** — this is the manual companion to automatic exception capture; both typically produce the same event family.

## Requirements

### Requirement: Canonical capture-exception behavior

The SDK SHALL implement the canonical `capture-exception` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Capturing a handled exception emits an exception event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception has stack information
- **WHEN** capture exception is called for an exception with type "TypeError" and message "boom"
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event properties should include:
  | property           | value     |
  | $exception_type    | TypeError |
  | $exception_message | boom      |
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
