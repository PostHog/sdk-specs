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
nextDelay(attempt): Duration
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
   - Legacy capture. Retryable: network errors, many server errors, rate limits / `429`, timeouts, and some transient transport errors. Non-retryable: malformed payloads, most 4xx client errors, or SDK-specific parse/serialization failures.
   - Capture v1. Retryable: exactly `408`, `500`, `502`, `503`, `504`, network errors and timeouts, plus the `retry` entries of a 2xx `results` map. Everything else is terminal, including `429`, which comes from a layer in front of capture and carries no `Retry-After`. See **Capture v1 status classification and attempt budget**.
6. **Apply retry policy for retryable failures.**
   - Retry after an exponential or linear backoff delay.
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
10. **Handle oversized batches specially (legacy capture).**
    - Some SDKs on legacy capture shrink batch size on `413 Payload Too Large` and retry rather than dropping the whole batch immediately.
    - On capture v1, `413` is terminal; byte-aware batching keeps every request under the body limit (see `event-batcher`).
11. **Allow wrapper SDKs to delegate queue ownership instead of creating a second queue.**
    - Flutter's Dart layer can preprocess or drop events before enqueue (`beforeSend`, screen-context injection, exception normalization), but successful `identify`, `capture`, `alias`, `group`, `flush`, and `close` calls are then forwarded into the underlying native/browser SDKs, where the actual queue, retry counters, and drop policy live.

## State & lifecycle

### State read

- queued events, stable queue-entry identities, and persisted queue contents
- retry counters, active flush-sequence state, and backoff policy state
- transport error metadata such as HTTP status
- network connectivity state where the SDK exposes it

### State written

- queue contents (enqueue, identity-based acknowledgement, terminal deletion, capacity eviction, explicit clear)
- retry counters / paused-until timestamps
- batch-size adaptation state in SDKs that shrink batches after `413` (legacy capture only)

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
- **HTTP client / transport** — supplies retryable vs non-retryable errors.
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

### Requirement: Ingestion retry backoff is jittered

The SDK SHOULD apply random jitter to each ingestion retry wait, so that clients refused together do not return together, and an SDK that does SHALL follow the rules below. Without it, every client that failed during an outage retries on the same schedule and arrives at the endpoint as one burst each time it recovers.

Jitter SHALL scale the delay the SDK computed for that attempt rather than replace the schedule: the exponential or linear progression, the retry budget, and the backoff ceiling are unchanged, and a jittered wait SHALL NOT exceed the ceiling the SDK configured for its own backoff. The jittered wait SHALL stay within a bounded factor of the computed delay — the SDKs that implement this use a factor drawn uniformly from a window around 1, such as `[0.75, 1.25]` or `[0.5, 1.5]` — so spreading a fleet neither retries far earlier than the schedule intends nor leaves a recovered endpoint idle.

A `Retry-After` the endpoint sent SHALL remain a floor applied after jitter. Spreading a fleet SHALL NOT move a retry earlier than the endpoint asked for. Where the SDK clamps `Retry-After` to its backoff ceiling, that clamp still applies and the clamped value is the floor.

Jitter is an availability measure, not a correctness one. An SDK whose platform offers no usable source of randomness, or whose randomness call fails, SHALL use the unjittered computed delay rather than skipping the wait.

#### Scenario: Retry waits vary around the computed delay
- **GIVEN** an SDK whose ingestion retry schedule computes a delay of 1000ms for the first retry
- **WHEN** many clients each take that first retry
- **THEN** their waits are not all 1000ms
- **AND** every wait stays within the SDK's bounded jitter factor of 1000ms

#### Scenario: A jittered wait never exceeds the backoff ceiling
- **GIVEN** an SDK whose backoff ceiling is 30 seconds
- **AND** the computed delay for this attempt has already reached the ceiling
- **WHEN** jitter is applied to that delay
- **THEN** the resulting wait is at most 30 seconds

#### Scenario: Retry-After stays a floor under a jittered wait
- **GIVEN** a retryable ingestion response carrying `Retry-After: 10` seconds
- **AND** the SDK's jittered delay for that attempt is 4 seconds
- **WHEN** the SDK schedules the retry
- **THEN** it waits at least 10 seconds, or at least its backoff ceiling where the SDK clamps
  `Retry-After` to a ceiling below 10 seconds
- **AND** where the SDK clamps `Retry-After`, the wait is still at most its backoff ceiling

#### Scenario: No randomness available falls back to the computed delay
- **GIVEN** an SDK whose source of randomness is unavailable or fails
- **WHEN** the SDK schedules a retry
- **THEN** it waits the unjittered computed delay
- **AND** it does not retry without waiting

### Requirement: Capture v1 status classification and attempt budget

An SDK that delivers events through capture v1 SHALL retry a capture request only on HTTP `408`, `500`, `502`, `503` and `504`, on a network error or timeout before a response is read, and for the `retry` entries of a 2xx `results` map. Every other response SHALL be terminal for the request, including `400`, `401`, `402` (billing limit; no per-event results, so every event in the request is reported lost), `404`, `413`, `415` and `429`. The SDK SHALL NOT fall back to a legacy endpoint on `404` and SHALL NOT split or halve the batch on `413`. A 2xx whose body is not a readable `results` map is terminal.

Each batch SHALL get at most four attempts by default (three retries), with the retry count configurable within a bounded range. The waits before the second, third and fourth attempts SHALL be 100 ms, 200 ms and 400 ms (100 ms doubling), each multiplied by a random factor in `[0.75, 1.25]`, and never above a 30 second ceiling. A `Retry-After` header SHALL raise the wait to at least its value, clamped to the ceiling, and the jitter SHALL never shorten it. `Retry-After` SHALL be honored on a retryable status and on a 2xx with `retry` entries. After the last attempt, every event still pending SHALL be reported as exhausted through the SDK's error surface. The SDK SHALL NOT keep the events for a later flush; the analytics and AI lanes of a capture v1 server SDK are in-memory queues, not durable queues.

Resends SHALL be SDK attempts, with the header rules in `capture`: the HTTP library's own retry mechanism SHALL be off for capture requests, because a library retry resends the stale `PostHog-Request-Timestamp` and attempt number.

Legacy capture: `429` was retried, several SDKs retried every `5xx`, and some shrank the batch on `413`. Whether capture v1 SDKs should retry `404` or `429` is under review; this requirement states today's rule.

#### Scenario: Retryable statuses are retried with doubling waits (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status   | body                                   |
  | <status> | {"error":"temporary"}                  |
  | <status> | {"error":"temporary"}                  |
  | 200      | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Retry Me"
- **AND** pending captures are flushed
- **THEN** exactly 3 capture request should have been received
- **AND** the first inter-request delay should be at least 75 milliseconds and at most 125 milliseconds
- **AND** the second inter-request delay should be at least 150 milliseconds and at most 250 milliseconds
- **AND** all recorded request attempts should be consecutive integers starting at one
  Examples:
  | status |
  | 408    |
  | 500    |
  | 502    |
  | 503    |
  | 504    |

#### Scenario: Terminal statuses are not retried and are reported (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status   | body                                        |
  | <status> | {"error":"<error>"}                         |
  | 200      | {"results":{"*":{"result":"ok"}}}           |
- **WHEN** capture is called with distinct id "user-123" and event "Final"
- **AND** pending captures are flushed
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** exactly 1 capture request should have been received
- **AND** the SDK should report the event "Final" as not delivered with status <status>
  Examples:
  | status | error                   |
  | 400    | request_parsing_error   |
  | 401    | invalid_api_token       |
  | 402    | billing_limit_exceeded  |
  | 404    | not_found               |
  | 413    | payload_too_large       |
  | 429    | rate_limited            |

#### Scenario: Retry-After raises the wait and jitter never lowers it (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | headers           | body                                   |
  | 503    | Retry-After: 3    | {"error":"service_unavailable"}        |
  | 200    |                   | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Wait"
- **AND** pending captures are flushed
- **THEN** exactly 2 capture request should have been received
- **AND** the first inter-request delay should be at least 3000 milliseconds

#### Scenario: Exhausted retries are reported after the last attempt (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1 and maximum retries 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                          |
  | 200    | {"results":{"*":{"result":"retry","details":"not_persisted"}}} |
  | 200    | {"results":{"*":{"result":"retry","details":"not_persisted"}}} |
- **WHEN** capture is called with distinct id "user-123" and event "Never Stored"
- **AND** pending captures are flushed
- **THEN** exactly 2 capture request should have been received
- **AND** the SDK should report the event "Never Stored" as exhausted with details "not_persisted"
- **AND** a later flush should send no further request for "Never Stored"

