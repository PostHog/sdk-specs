# Flush Specification

## Purpose

`flush` forces the SDK to attempt immediate delivery of any currently queued events instead of waiting for the normal batch-size or timer-based flush conditions.

It is mainly used when callers need stronger delivery guarantees before a boundary such as:

- app backgrounding / termination
- script exit
- serverless request completion
- tests that need deterministic delivery

## Applicability

`both` — client and server SDKs commonly expose `flush`, but with different operational meaning.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Primary use | Best-effort immediate upload of queued events before app/lifecycle transitions. | Drain the in-process event queue before process/request shutdown. |
| Return type | Often `void` on native/mobile SDKs; Promise on js-core-based SDKs. | Often Promise / blocking call until the queue drains. |
| Replay/snapshot queues | Some SDKs flush both the normal analytics queue and replay/snapshot queues. | Usually just the analytics/event queue. |
| Failure surfacing | Native client SDKs often swallow/log errors; js-core Promise can reject. | Server SDKs more commonly surface failure through rejection or by blocking until worker completion. |

## Public signatures

### Canonical signature

```ts
flush(): void | Promise<void>
```

### Surface variants

- **posthog-js core / react-native:** `flush(): Promise<void>`
- **Flutter:** `flush(): Future<void>`
- **Node:** `flush(): Promise<void>`
- **Ruby:** `flush(): void`
- **iOS:** `flush(): void`
- **Android:** `flush(): void`
- **Unity:** `Flush(): void`
- **Python:** `flush(): void`

## Behavior

1. **Check whether there is anything pending to send.** If the queue is empty, return immediately.
2. **Bypass normal wait conditions.** Do not wait for `flushAt` or `flushInterval`; attempt delivery now.
3. **Build and send batches until the queue is drained or a failure stops progress.**
4. **Flush related queues when the SDK has them.** Native mobile/client SDKs may also flush replay/snapshot queues.
5. **Return when the current flush cycle is complete.**
   - Promise-based SDKs resolve/reject when the cycle finishes.
   - Void-returning SDKs fire-and-forget the flush on their internal queue/thread/coroutine.

## State & lifecycle

### State read

- pending event queue
- batching configuration (`maxBatchSize`, queue state)
- SDK enabled / opt-out state
- replay/snapshot queue state in SDKs that have separate channels

### State written

- pending queue contents (successful sends remove items)
- retry/backoff state if the flush encounters retryable failures
- internal in-flight flush promise / lock state

### Lifecycle behavior

- `flush()` is often called automatically during shutdown/background transitions.
- Explicit caller-triggered flush uses the same queue and transport machinery as timer/threshold-triggered flushes.
- On Promise-based SDKs, repeated flush calls are usually serialized/deduplicated around the current in-flight flush.

## Error handling

- Client/native SDKs often log and swallow flush failures.
- js-core-based Promise APIs may reject on transport/HTTP failures.
- Python blocks on `queue.join()`; failure handling primarily happens in the consumer thread rather than by raising from `flush()` itself.
- `flush()` should not crash application code under normal conditions.

## Concurrency & ordering guarantees

- Flush drains queued events in FIFO batch order, subject to the surrounding batcher/retry queue behavior.
- Concurrent flush requests are commonly serialized so only one drain runs at a time.
- Events enqueued during a flush may be included in the current drain or left for the next cycle depending on implementation timing.

## Interactions

- **retry-queue / event-batcher** — `flush()` forces those internal components to attempt immediate delivery.
- **shutdown / close** — often implemented as `flush()` plus worker/timer teardown.
- **session replay / snapshot queues** — some client SDKs flush these alongside normal analytics events.
- **opt-out / consent gating** — if the SDK is opted out, future enqueue is blocked; already-queued events may or may not still be flushed depending on SDK policy.

## Requirements

### Requirement: Canonical flush behavior

The SDK SHALL implement the canonical `flush` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Flush immediately sends queued events (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains events:
  | event      | distinct_id |
  | First      | user-123    |
  | Second     | user-123    |
- **WHEN** flush is called
- **THEN** the mock server should receive a batch containing events:
  | event  |
  | First  |
  | Second |
- **AND** the event queue should be empty after a successful flush

#### Scenario: Flush is safe when the queue is empty (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue is empty
- **WHEN** flush is called
- **THEN** the call should not throw
- **AND** no network request should be sent

#### Scenario: Flush keeps events retryable when delivery fails (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **AND** the mock server will fail the next ingestion request with status 503
- **WHEN** flush is called
- **THEN** the call should not throw
- **AND** the event named "Save" should remain queued for retry
