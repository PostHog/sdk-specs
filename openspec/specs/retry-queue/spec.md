# Retry Queue Specification

## Purpose

`retry-queue` is the internal durability and retry mechanism that ensures captured events are not immediately lost when delivery fails transiently.

It sits between event creation and successful upload, handling:

- queueing / buffering
- backpressure when producers outpace uploads
- retry decisions
- retry timing / backoff
- dropping or deleting events on non-retryable failures

This is not a single public API. It is the internal reliability layer behind `capture`, `identify`, `alias`, `group-identify`, and other event-producing methods.

## Applicability

`both` — client and server SDKs both have retry/batching layers, though the implementations differ. Some wrapper SDKs, such as Flutter, do not own a second retry queue and instead delegate queue/retry state to the underlying native/browser SDK.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
enqueue(event): boolean | void
flush(): Promise<void> | void
retryLoop(batch): void
shouldRetry(error): boolean
nextDelay(attempt, retryAfterHeader?): Duration
```

## Behavior

1. **Accept events into a local queue/buffer.**
   - Events are appended to an in-memory queue, persisted queue, file-backed queue, or batch channel depending on SDK.
   - Some SDKs cap queue size and drop when full.
2. **Flush in batches or on timers.**
   - Batches are built according to queue size, configured batch size, flush interval, or explicit flush requests.
3. **Attempt upload.**
   - The batch is sent to PostHog using the configured HTTP transport.
4. **Classify failures.**
   - Retryable: network errors, many server errors, rate limits / `429`, timeouts, and some transient transport errors.
   - Non-retryable: malformed payloads, most 4xx client errors, or SDK-specific parse/serialization failures.
5. **Apply retry policy for retryable failures.**
   - Retry after an exponential or linear backoff delay.
   - Respect `Retry-After` when the transport exposes it.
   - Some SDKs pause flushing globally until the backoff window expires.
6. **Preserve queued events for retry.**
   - Retryable failures keep the same events in the queue/storage for a later attempt.
   - Successful sends delete/remove the events from the queue/storage.
7. **Drop or delete on terminal failure.**
   - If a batch is non-retryable, the events are dropped/deleted.
   - Some SDKs also drop after a maximum retry count is exceeded.
8. **Handle oversized batches specially.**
   - Some SDKs shrink batch size on `413 Payload Too Large` and retry rather than dropping the whole batch immediately.
9. **Allow wrapper SDKs to delegate queue ownership instead of creating a second queue.**
   - Flutter's Dart layer can preprocess or drop events before enqueue (`beforeSend`, screen-context injection, exception normalization), but successful `identify`, `capture`, `alias`, `group`, `flush`, and `close` calls are then forwarded into the underlying native/browser SDKs, where the actual queue, retry counters, and drop policy live.

## State & lifecycle

### State read

- queued events / event ids / persisted queue contents
- retry counters and backoff policy state
- transport error metadata such as HTTP status or `Retry-After`
- network connectivity state where the SDK exposes it

### State written

- queue contents (enqueue, dequeue, delete, clear)
- retry counters / paused-until timestamps
- batch-size adaptation state in SDKs that shrink batches after `413`

### Lifecycle behavior

- Queues are initialized during SDK startup.
- Flushes happen on timers, explicit `flush()`, queue size thresholds, lifecycle events, or worker loops.
- Some SDKs preserve queued events across app restarts (persistent queue / file-backed queue).
- On shutdown, implementations may attempt a final drain/flush or wait for pending writes.
- Wrapper SDKs may have no queue lifecycle of their own. Flutter keeps no separate Dart-side queued-event store; its mobile wrapper forwards event-producing calls and explicit `flush()` / `close()` into the native SDKs, while Flutter Web forwards event calls to `posthog-js` and does not add an additional wrapper-managed retry queue.

## Error handling

- Retry-queue failures should not crash application code.
- Serialization or parse failures of individual persisted events are logged and often cause only those corrupted events/files to be deleted.
- Non-retryable server/client errors are logged and dropped rather than retried forever.
- Retry exhaustion usually results in dropping events or leaving them unsent depending on SDK policy.

## Concurrency & ordering guarantees

- Ordering is usually FIFO within a queue or persisted event list, but batch boundaries and retries can delay later items behind earlier failures.
- Queue mutation is synchronized with locks, thread-safe queues/channels, or serialized JS execution.
- Most SDKs guarantee at-least-once best effort, not exactly-once delivery.
- Concurrent producers can enqueue while a flush is in progress; backpressure behavior when full is SDK-specific.

## Interactions

- **`capture` / `identify` / `alias` / `group-identify`** — feed events into the retry queue.
- **persistent storage** — backs durable queues on client SDKs that survive restarts.
- **HTTP client / transport** — supplies retryable vs non-retryable errors and `Retry-After` metadata.
- **consent gating / opt-out** — may prevent enqueue entirely or clear queued events in some SDKs.
- **before-send-hook / wrapper preprocessing** — some wrappers can modify or drop events before they ever reach the queue. Flutter's Dart `beforeSend` callbacks and exception/screen preprocessing run before delegated native/browser enqueue.
- **flush()** — forces the retry queue to attempt immediate delivery.

## Requirements

### Requirement: Canonical retry-queue behavior

The SDK SHALL implement the canonical `retry-queue` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Retry queue keeps events after transient failure
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will fail the next ingestion request with status 503
- **WHEN** capture is called with event "Retry Me"
- **AND** flush is called
- **THEN** the event named "Retry Me" should remain queued for retry

#### Scenario: Retry queue delivers events after a later success
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event named "Retry Me" is queued for retry
- **AND** the mock server will accept the next ingestion request with status 200
- **WHEN** retry queue processing runs
- **THEN** the mock server should receive event "Retry Me"
- **AND** the event named "Retry Me" should be removed from the retry queue

#### Scenario: Retry queue drops or bounds events when capacity is exceeded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and retry queue capacity is 2
- **WHEN** three events are added to the retry queue
- **THEN** the retry queue size should be 2
- **AND** the SDK should record a queue capacity warning
