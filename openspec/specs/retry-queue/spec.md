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

`both` — client and server SDKs both have retry/batching layers, though the implementations differ. Requirements that explicitly refer to a bounded durable queue apply when an SDK owns storage intended to survive a process or application restart; they do not require page-lifetime best-effort buffers to become persistent. Some wrapper SDKs, such as Flutter, do not own a second retry queue and instead delegate queue/retry state to the underlying native/browser SDK.

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
3. **Pause while positively known to be offline.**
   - When the platform reports that no network is available, do not start a transport request or consume a flush retry attempt.
   - Continue accepting records subject to queue capacity, and make queued work eligible for normal processing when connectivity returns.
   - If connectivity state is unknown or unavailable, attempt delivery and classify any resulting transport failure normally.
4. **Attempt upload.**
   - The batch is sent to PostHog using the configured HTTP transport.
5. **Classify failures.**
   - Retryable: network errors, many server errors, rate limits / `429`, timeouts, and some transient transport errors.
   - Non-retryable: malformed payloads, most 4xx client errors, or SDK-specific parse/serialization failures.
6. **Apply retry policy for retryable failures.**
   - Retry after an exponential or linear backoff delay and respect `Retry-After` when the transport exposes it.
   - Some SDKs pause flushing globally until the backoff window expires.
   - A retry-count budget may end an active failure-driven flush sequence, but it is independent from retention in a bounded durable queue.
7. **Preserve durable queued events for retry.**
   - Retryable failures keep the same durable entries in queue storage for a later attempt, including after an active retry sequence ends.
   - Later independent triggers such as a timer, connectivity recovery, queue threshold, explicit flush, or relaunch can start another attempt sequence subject to the current cooldown.
   - Queue capacity and its documented eviction order bound retained storage.
8. **Acknowledge successful sends by queue-entry identity.**
   - A flush snapshots a stable identity for each included queue entry, such as a persisted filename, guaranteed-unique event id, or equivalent queue-owned token.
   - Success removes only matching entries still present in the live queue, not the current first N positions.
   - If capacity eviction replaced in-flight entries, their later acknowledgement must not remove the never-sent replacements.
9. **Drop or delete only records with a terminal disposition.**
   - A non-retryable response can remove the affected batch or record, but not unrelated queue entries.
   - Retry-budget exhaustion alone is not a terminal disposition for a bounded durable queue and must not clear it.
10. **Handle oversized batches specially.**
    - Some SDKs shrink batch size on `413 Payload Too Large` and retry rather than dropping the whole batch immediately.
11. **Allow wrapper SDKs to delegate queue ownership instead of creating a second queue.**
    - Flutter's Dart layer can preprocess or drop events before enqueue (`beforeSend`, screen-context injection, exception normalization), but successful `identify`, `capture`, `alias`, `group`, `flush`, and `close` calls are then forwarded into the underlying native/browser SDKs, where the actual queue, retry counters, and drop policy live.

## State & lifecycle

### State read

- queued events, stable queue-entry identities, and persisted queue contents
- retry counters, active flush-sequence state, and backoff policy state
- transport error metadata such as HTTP status or `Retry-After`
- network connectivity state where the SDK exposes it

### State written

- queue contents (enqueue, identity-based acknowledgement, terminal deletion, capacity eviction, explicit clear)
- retry counters / paused-until timestamps
- batch-size adaptation state in SDKs that shrink batches after `413`

### Lifecycle behavior

- Queues are initialized during SDK startup.
- Flushes happen on timers, explicit `flush()`, queue size thresholds, connectivity recovery, lifecycle events, or worker loops.
- A positive offline signal pauses transport attempts without preventing durable enqueue.
- Some SDKs preserve queued events across app restarts (persistent queue / file-backed queue).
- On shutdown, implementations may attempt a final drain/flush or wait for pending writes.
- Wrapper SDKs may have no queue lifecycle of their own. Flutter keeps no separate Dart-side queued-event store; its mobile wrapper forwards event-producing calls and explicit `flush()` / `close()` into the native SDKs, while Flutter Web forwards event calls to `posthog-js` and does not add an additional wrapper-managed retry queue.

## Error handling

- Retry-queue failures should not crash application code.
- Serialization or parse failures of individual persisted events are logged and often cause only those corrupted events/files to be deleted.
- Non-retryable server/client errors are logged and may remove only the affected batch or record rather than unrelated queued entries.
- Exhausting a retry budget may stop the active failure-driven flush sequence. It does not authorize deleting records from a bounded durable queue.

## Concurrency & ordering guarantees

- Ordering is usually FIFO within a queue or persisted event list, but batch boundaries and retries can delay later items behind earlier failures.
- Queue mutation is synchronized with locks, thread-safe queues/channels, or serialized JS execution.
- Most SDKs guarantee at-least-once best effort, not exactly-once delivery.
- Concurrent producers can enqueue while a flush is in progress; backpressure behavior when full is SDK-specific.
- Events captured while an earlier batch is in flight, including replacement events added to a queue that hit capacity mid-flush, MUST remain queued and be delivered by a subsequent flush — SDKs must not drop them by mistaking them for the batch that was just sent.

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

#### Scenario: Events captured while a full queue is flushing are preserved, not dropped
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and retry queue capacity is 3
- **AND** the mock server will delay the next ingestion request until released
- **WHEN** three events named "initial-1", "initial-2", and "initial-3" are added to the retry queue
- **AND** flush is called
- **AND** three replacement events named "replacement-1", "replacement-2", and "replacement-3" are added to the retry queue while the flush is in flight
- **AND** the delayed ingestion request is released and succeeds
- **THEN** the mock server should receive events "initial-1", "initial-2", and "initial-3" in the first batch
- **AND** the three replacement events should remain queued for delivery
- **AND** a subsequent flush should deliver the three replacement events

### Requirement: Durable queue retention is independent from flush retry scheduling

When an SDK owns a bounded durable queue, it MUST retain the affected queue entries after a retryable delivery failure, including when the failure-driven flush sequence exhausts its retry-count budget. Exhausting that budget MAY end the active sequence, but MUST NOT delete or clear queued entries.

A durable queue entry MAY be removed only when its exact entry is acknowledged successfully, it receives a terminal non-retryable disposition, capacity eviction selects it, or an explicit documented lifecycle operation clears it. Retry attempts MUST use bounded backoff, and later independent flush triggers MUST be able to retry retained entries subject to the current cooldown.

#### Scenario: Pre-response transport failures exceed the retry budget
- **GIVEN** a bounded durable queue containing event "Keep Me"
- **AND** the normal retry-count budget permits 2 retries after the initial ingestion attempt
- **WHEN** 3 attempts fail with a recognized transient transport error before any HTTP response
- **THEN** event "Keep Me" remains durably queued
- **AND** ending the active retry sequence does not clear any queued entry

#### Scenario: Retryable HTTP failures exceed the retry budget
- **GIVEN** a bounded durable queue containing event "Retry Later"
- **AND** the normal retry-count budget permits 2 retries after the initial ingestion attempt
- **WHEN** 3 attempts receive HTTP 503
- **THEN** event "Retry Later" remains durably queued
- **WHEN** a later independent flush receives HTTP 200
- **THEN** event "Retry Later" is delivered and removed

### Requirement: Known-offline queues pause delivery attempts

When the SDK can positively determine that the network is unavailable, it MUST pause queue transport attempts without consuming the flush retry budget. It MUST continue to accept records subject to the existing capacity policy. When connectivity returns, queued work MUST become eligible for normal flush processing again. Unknown or unavailable connectivity state MAY fall back to an attempted request and normal transport-error handling.

#### Scenario: Offline queue resumes after connectivity returns
- **GIVEN** the SDK reports that the network is unavailable
- **WHEN** event "Captured Offline" is added and queue timers run
- **THEN** no ingestion request is attempted
- **AND** no flush retry attempt is consumed
- **AND** event "Captured Offline" remains queued
- **WHEN** the network becomes available and queue processing runs
- **THEN** event "Captured Offline" is delivered

### Requirement: Successful flushes acknowledge queue entries by identity

A flush MUST snapshot stable identities for the queue entries included in its request. After success, it MUST remove only matching entries that are still present in the live queue. It MUST NOT acknowledge a batch by deleting the current first N queue positions when those positions may have changed during transport.

#### Scenario: Full queue is replaced with identical payloads during an in-flight flush
- **GIVEN** a durable queue with capacity 3 whose entries have queue identities "initial-1", "initial-2", and "initial-3"
- **AND** all three entries contain the same serialized event payload
- **AND** a flush snapshots those three queue identities
- **WHEN** entries with queue identities "replacement-1", "replacement-2", and "replacement-3" and the same serialized payload are accepted
- **AND** capacity eviction replaces the three initial entries
- **AND** the in-flight flush succeeds
- **THEN** queue identities "replacement-1", "replacement-2", and "replacement-3" remain queued
- **AND** a later flush delivers the three replacement entries
