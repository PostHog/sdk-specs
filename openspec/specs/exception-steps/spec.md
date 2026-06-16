# Exception Steps Specification

## Purpose

`exception-steps` lets the host app record **breadcrumb-style context records** ("steps") over time; the SDK keeps a rolling, byte-bounded buffer of these steps for the lifetime of the SDK instance and attaches a snapshot of it to **every** captured `$exception` event as `$exception_steps`, giving the PostHog error-tracking UI a timeline of recent activity leading up to each error.

Steps are recorded manually via a public API in v1 — automatic breadcrumbs (navigation, console, network) are out of scope.

The buffer lives for the SDK instance: two exceptions close together carry overlapping steps, exceptions further apart carry the delta that survives byte-budget eviction. A clean launch starts with an empty buffer and closing the SDK clears it; a user identity change (`reset()` or a new `identify`) does **not** — steps are application-activity breadcrumbs, and the captured user is recorded on the `$exception` event itself.

The reference implementation is the browser SDK ([posthog-js#3389](https://github.com/PostHog/posthog-js/pull/3389)): `@posthog/core` ErrorTracking primitives wired in `packages/browser/src/posthog-exceptions.ts`, source of the public API, buffer, and serialization primitives. The crash-durable persistence requirement traces to the iOS port, where PLCrashReporter reconstructs the crash `$exception` on the next launch.

## Applicability

`client` — single-user client SDKs that support error tracking. Each SDK instance has exactly one user/timeline, so one global buffer per instance is correct. Server / multi-tenant SDKs need request/context-scoped buffers and are explicitly out of scope until a follow-up defines that model.

## Public signatures

### Canonical client signature

```ts
addExceptionStep(
  message: string,
  properties?: Record<string, JsonValue>,
): void
```

### Surface variants

- **posthog-js browser:** `addExceptionStep(message, properties?) => void`
- **iOS:** `addExceptionStep(_ message: String, properties: [String: Any]? = nil)` (plus a no-properties overload, both `@objc`-exposed)
- **Android:** `addExceptionStep(message: String, properties: Map<String, Any>? = null)`
- **flutter:** `addExceptionStep(String message, {Map<String, Object?>? properties})`
- **react-native:** `addExceptionStep(message, properties?) => void`
- **Unity:** `AddExceptionStep(string message, Dictionary<string, object> properties = null)`

The method lives alongside the SDK's existing `captureException` API.

## Configuration

Each SDK exposes an exception-steps config on its error-tracking options, named per the SDK's convention (`exceptionSteps` / `exception_steps`):

- `enabled` — default `true`
- `maxBytes` / `max_bytes` — total UTF-8 byte budget for the buffer, default `32768`

## Behavior

1. **Guard / no-op if disabled.** When the feature is disabled, recording does nothing and nothing is attached.
2. **Validate the message.** Empty, missing, or non-string messages are ignored with a logged warning; the call never throws.
3. **Capture `$timestamp` at call time** on the calling thread.
4. **Strip reserved keys** (`$message`, `$timestamp`) from user-supplied properties with a warning; the SDK sets the canonical values.
5. **Normalize the step to its JSON-safe wire form once**, using the SDK's existing event-property normalizer, before any byte-counting, storage, or persistence.
6. **Enforce the byte budget.** Evict oldest steps until the total fits within `maxBytes`; reject outright a single step larger than the budget.
7. **Append to the instance's FIFO buffer** synchronously, so the call returns only once the step is recorded and a step recorded immediately before a crash is already buffered. Fatal-crash-capable SDKs hold the buffer in memory and make it crash-durable — preferably by flushing it to disk from the crash handler at crash time, falling back to synchronous per-step persistence only where a crash-time flush isn't possible (see "Crash-durable persistence").
8. **On `$exception` capture:** attach a snapshot of the buffered steps as `$exception_steps`, only if the caller did not supply that key. The buffer is left intact for subsequent exceptions.

## State & lifecycle

### State read

- exception-steps configuration (`enabled`, `maxBytes`)
- the buffered steps at `$exception` capture time
- on fatal-crash SDKs: the persisted steps when reconstructing a crash `$exception` on the next launch

### State written

- the in-memory step buffer (append, byte-budget eviction; cleared on a clean launch or `close()`, not by capture or identity changes)
- on fatal-crash SDKs: the durable step store — written from the crash handler at crash time where possible, otherwise synchronously as steps are recorded — and cleared once the crashed run's steps have been attached on the next launch
- the `$exception_steps` property on the outgoing `$exception` event

## Error handling

- Recording never throws into the host app: invalid messages are ignored with a warning, and internal failures (e.g. serialization) silently skip the step.
- Serialization uses the SDK's event-property normalizer, so unrepresentable values are handled exactly as they would be on a normal event.
- Reserved keys in user properties are stripped with a warning rather than rejected.

## Concurrency & ordering guarantees

- `$timestamp` is captured synchronously on the caller's thread, and recording is synchronous: normalization, byte-budget enforcement, and buffer mutation complete before `addExceptionStep` returns, so a step recorded immediately before an exception or a crash is never lost to a pending background write. Recording must stay efficient — bounded, allocation-light work that adds negligible latency, even when it touches disk.
- Buffer access is thread-safe between the recording and capture paths.
- FIFO order is preserved: `$exception_steps` is always oldest → newest, and eviction removes from the oldest end.

## Interactions

- **`capture-exception` / the `$exception` capture path** is the attach point: a snapshot of the buffered steps is added to the event as `$exception_steps` (only if the caller did not supply that key).
- **Instance lifecycle:** the buffer belongs to the SDK instance — it rotates only by byte budget, is cleared on a clean launch and when the SDK is closed/shut down, and is **not** cleared by a user identity change (`reset()` / `identify`).
- **Embedded native SDK (hybrid SDKs):** a managed-layer SDK (Dart/JS/C#) that embeds a native crash-capturing SDK forwards each recorded step to the native layer so that native crashes carry the same steps — one logical buffer across layers (see "Hybrid (multi-layer) SDKs").
- **Crash reporting:** durability is only required where the crash `$exception` is reconstructed **after process death** (e.g. crash-reporter flows like PLCrashReporter on iOS). There the buffer is kept in memory and made durable through the platform's existing crash-context persistence (never a parallel store), preferably by flushing it from the crash handler at crash time rather than writing on every step. SDKs whose fatal exceptions are captured in-process and ride the existing persisted event queue (e.g. a JVM `UncaughtExceptionHandler`) may stay purely in-memory, since steps attach before the event is persisted.

## Requirements

### Requirement: Public exception-step API

Each target client SDK SHALL expose a public method to record an exception step, using the SDK's idiomatic naming and signature, placed alongside the SDK's existing `captureException`/`capture` method. The method SHALL accept a required message and an optional bag of user-supplied properties. Where the SDK exposes a cross-language interop surface (e.g. Swift → Objective-C), the method SHALL be declared so it is callable from that surface with interop-compatible types.

#### Scenario: Recording a step
- **WHEN** the host app calls `addExceptionStep("User tapped Checkout", { screen: "cart" })`
- **THEN** a step `{ $message: "User tapped Checkout", $timestamp: <call-time>, screen: "cart" }` is added to the SDK instance's buffer

#### Scenario: Empty or invalid message is ignored
- **WHEN** the host app calls `addExceptionStep` with an empty, missing, or non-string message
- **THEN** no step is buffered, the SDK logs a warning, and the call does not throw

#### Scenario: Recording never throws
- **WHEN** recording a step fails internally (e.g. serialization error)
- **THEN** the failure is swallowed, the step is silently skipped, and the host app is not affected

#### Scenario: Callable across interop boundary
- **WHEN** the SDK has an Objective-C (or equivalent) interop surface and a host calls the method from that surface
- **THEN** the method is exposed with interop-compatible types and records a step identically to the native call

### Requirement: Wire format of attached steps

Steps attached to an exception SHALL be serialized as an ordered array (oldest → newest) on the `$exception` event under the key `$exception_steps`. Each element SHALL contain a non-empty string `$message` and a `$timestamp` that is an ISO-8601 string or epoch number, plus any user-supplied properties.

#### Scenario: Ordered attachment
- **WHEN** steps A, B, C are recorded in that order and an exception is captured
- **THEN** `$exception_steps` equals `[A, B, C]` (oldest first)

#### Scenario: Reserved keys are stripped
- **WHEN** a user supplies `$message` or `$timestamp` inside the properties bag
- **THEN** those keys are removed (the SDK sets the canonical values), a warning is logged, and the remaining user properties are preserved

### Requirement: FIFO byte-budget buffer

The buffer SHALL be a FIFO queue bounded by a configurable maximum total UTF-8 byte size (`maxBytes`, default 32768). When adding a step would exceed the budget, the SDK SHALL evict the **oldest** steps until the total is within budget, keeping the steps closest in time to the exception.

#### Scenario: Oldest steps evicted under pressure
- **WHEN** the cumulative byte size of buffered steps exceeds `maxBytes`
- **THEN** the oldest steps are dropped first until the total is within `maxBytes`

#### Scenario: Single oversized step rejected
- **WHEN** a single serialized step is larger than `maxBytes`
- **THEN** the step is rejected outright and not added, and previously buffered steps are retained

#### Scenario: Byte counting uses UTF-8 byte length
- **WHEN** a step contains multi-byte characters
- **THEN** the budget is measured by UTF-8 byte length of the serialized step, not character count

### Requirement: Crash-safe serialization

Serializing a step SHALL never throw. The SDK SHALL serialize each step using the **same normalizer it applies to regular event properties** (see "Normalize to the wire form once"), so steps and events handle exotic values identically. Values that the normalizer cannot represent as JSON SHALL be handled exactly as they are for event properties — typically dropped, or rewritten where the normalizer already does so (e.g. dates → ISO-8601). A serialization failure SHALL cause the step to be silently skipped.

The specific transforms are SDK-dependent and need not match any other SDK; the only hard requirements are: never throw, and produce output identical to how the SDK would serialize the same values inside a normal event. (For reference, the browser SDK additionally rewrites circular references to a sentinel, error objects to `{ name, message, stack }`, and big integers to strings — other SDKs MAY do the same where idiomatic but are not required to.)

#### Scenario: Never throws on an unrepresentable value
- **WHEN** a step property holds a value the SDK's event-property normalizer cannot serialize (e.g. a circular reference or a non-JSON object)
- **THEN** the step serializes without throwing, the value is handled the same way it would be on a normal event, and if serialization still fails the step is silently skipped

#### Scenario: Matches event-property serialization
- **WHEN** a value type (e.g. a `Date`) appears both in a step and in a normal event's properties
- **THEN** it is serialized identically in both

### Requirement: Normalize to the wire form once, before processing

The SDK SHALL normalize each step to its JSON-safe wire form **once** — using the same normalization the SDK applies to event properties — **before** measuring its byte size, storing it in the buffer, persisting it to disk for crash durability, or attaching it to an exception. All of these representations SHALL be identical, so the byte budget reflects exactly what is stored, persisted, and sent, and no second, divergent normalization happens at attach or capture time.

#### Scenario: Normalized form is consistent everywhere
- **WHEN** a step contains values that normalization rewrites (e.g. a `Date`/`URL`) or drops (non-serializable values)
- **THEN** the normalized values are what gets byte-counted, retained in the buffer, persisted for crash durability, and attached to the exception — identical in every representation

#### Scenario: Persisted steps are already normalized
- **WHEN** steps are written to disk for a fatal-crash SDK
- **THEN** the persisted form is the normalized wire form, so the next-launch attachment needs no further normalization and the on-disk byte size matches the in-memory budget

### Requirement: Attach semantics and buffer lifetime

On exception capture the SDK SHALL attach a snapshot of the buffered steps to `$exception_steps` only if the caller did not already provide that key. The buffer is a rolling window, scoped to the lifetime of the SDK instance, that every exception reads from: it SHALL persist across captures and across user identity changes (e.g. `reset()` or a new `identify`), rotating in the meantime only by byte-budget eviction. It SHALL be cleared only on a clean launch (a fresh start with no pending crash) or when the SDK is closed/shut down. When the feature is disabled, recording SHALL be a no-op and nothing SHALL be attached.

#### Scenario: Attach only when absent
- **WHEN** the caller captures an exception and already provides `$exception_steps`
- **THEN** the SDK does not overwrite it with buffered steps

#### Scenario: Steps persist across captures
- **WHEN** steps A, B, C are recorded, one exception is captured, step D is then recorded, and a second exception is captured
- **THEN** the first exception carries `[A, B, C]` and the second carries `[A, B, C, D]` (subject to byte-budget eviction)

#### Scenario: Identity change does not clear the buffer
- **WHEN** steps are recorded, the current user changes (e.g. `reset()` or a new `identify`), and an exception is then captured
- **THEN** the exception still carries the steps recorded before the identity change

#### Scenario: Buffer cleared on a clean launch or close
- **WHEN** the SDK is closed, or the process starts again cleanly with no pending crash report
- **THEN** the new instance's buffer starts empty

#### Scenario: Disabled is a no-op
- **WHEN** the feature is configured disabled
- **THEN** `addExceptionStep` records nothing and no `$exception_steps` are attached

### Requirement: Single-instance isolation

Each SDK instance SHALL own exactly one logical buffer for the lifetime of the instance (single-user client model). Steps SHALL NOT be shared across instances. A hybrid SDK spanning multiple layers (see "Hybrid (multi-layer) SDKs") is still one instance with one logical buffer, even if that buffer is mirrored across layers.

#### Scenario: One buffer per instance
- **WHEN** two SDK instances each record steps
- **THEN** each instance's exceptions carry only that instance's steps

### Requirement: Accurate timestamps and synchronous, efficient recording

The `$timestamp` SHALL be captured at call time on the calling thread. Recording SHALL be synchronous: normalization, byte-budget enforcement, and buffer mutation SHALL complete before `addExceptionStep` returns, so a step recorded immediately before an exception or a crash is present in the buffer when it is captured — the SDK SHALL NOT defer the work to a background queue that a crash could pre-empt. Recording SHALL nonetheless stay efficient — bounded, allocation-light work that adds negligible latency to the caller, even on SDKs where it touches disk. Buffer access SHALL be thread-safe across the recording and capture paths.

#### Scenario: Timestamp reflects call time
- **WHEN** a step is recorded
- **THEN** its `$timestamp` reflects the moment `addExceptionStep` was called

#### Scenario: Last step before a crash is recorded
- **WHEN** a step is recorded immediately before the process crashes, with no further SDK activity in between
- **THEN** that step is already in the buffer when the crash is captured, because recording completed synchronously rather than on a deferred queue

#### Scenario: Concurrent access is safe
- **WHEN** `addExceptionStep` and the capture path run on different threads simultaneously
- **THEN** the buffer remains consistent and the operations do not corrupt state

### Requirement: Crash-durable persistence for fatal-crash SDKs

For any SDK that captures fatal crashes (where the crashing `$exception` is reported on the next process launch), buffered steps SHALL be persisted durably such that steps recorded before the crash survive process death and are attached to the crash `$exception` on the next launch. The persisted store SHALL integrate with the platform's existing crash-context persistence where one exists rather than introduce a parallel, independently-ordered store. SDKs that do not capture fatal crashes MAY use an in-memory buffer.

The buffer SHALL be held in memory during the run. Persistence SHALL be achieved **preferably by flushing the in-memory buffer to disk from the crash handler at crash time**, so the normal path does no per-step disk I/O. Where flushing from the crash handler is not possible or not safe on the platform, the SDK SHALL fall back to persisting synchronously as steps are recorded, keeping that write efficient. Either way the persisted form is the normalized wire form (see "Normalize to the wire form once") and is bounded by `maxBytes`.

A fatal crash ends the run. The crashed run's persisted steps belong only to the crash `$exception`: once they have been attached on the next launch they SHALL be cleared so they are not re-attached and do not carry into the new instance's buffer. A clean shutdown (`close()`) SHALL likewise clear the persisted store, so a subsequent clean launch starts empty.

#### Scenario: Steps survive a fatal crash
- **WHEN** steps are recorded and the process then dies from a fatal crash before any capture
- **THEN** on the next launch those steps are read back and attached to the `$exception` reported for that crash

#### Scenario: Persistence prefers a crash-time flush over per-step disk writes
- **WHEN** an SDK can flush its in-memory buffer from the crash handler
- **THEN** it keeps steps in memory during normal operation and writes them to the durable store at crash time, rather than persisting on every `addExceptionStep`

#### Scenario: Persisted crash steps do not bleed into the next launch
- **WHEN** the crashed run's steps have been attached to the crash `$exception` on next launch
- **THEN** the persisted steps are cleared, so they are not attached again and the new instance's buffer starts empty

#### Scenario: In-memory fallback when no fatal-crash capture
- **WHEN** an SDK does not capture fatal crashes
- **THEN** an in-memory, instance-lifetime buffer is sufficient

### Requirement: Hybrid (multi-layer) SDKs

For an SDK composed of a managed layer (e.g. Dart, JavaScript, C#) embedding a native SDK that captures fatal crashes (e.g. posthog-ios / posthog-android), errors are captured on different layers: the managed layer captures managed-runtime errors in-process, while the native SDK captures fatal native crashes (often reconstructed on the next launch). The public `addExceptionStep` records on the managed layer, but the buffer SHALL behave as one logical buffer shared across both layers so an `$exception` captured on either layer carries the same steps.

Each step recorded on the managed layer SHALL be forwarded — in its normalized wire form (see "Normalize to the wire form once") — to the embedded native SDK, which retains it under the same FIFO byte-budget rules and persists it via the crash-durable store. The managed and native buffers SHALL therefore converge to identical contents, so a native crash reconstructed on the next launch carries the steps recorded before it. A given `$exception` SHALL carry the shared buffer's steps exactly once; the attach-if-absent rule prevents any layer from attaching a second time. Clearing (clean launch, `close()`, post-crash cleanup) SHALL apply across both layers, and a user identity change SHALL clear neither.

#### Scenario: Native crash carries managed-layer steps
- **WHEN** the app records steps through the managed-layer `addExceptionStep` and the process then dies from a native crash before any capture
- **THEN** on the next launch the native crash `$exception` carries those steps, because they were forwarded to and persisted on the native layer before the crash

#### Scenario: Steps are not duplicated across layers
- **WHEN** an exception is captured on one layer and already has `$exception_steps` attached
- **THEN** no other layer attaches or appends the shared buffer's steps again

