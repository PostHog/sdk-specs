# Event Batcher Specification

## Purpose

`event-batcher` is the internal component that groups individual events into uploadable batches based on queue size, batch size, and time thresholds.

It exists to reduce request overhead and improve throughput by sending multiple events together instead of one request per event.

This component is distinct from the retry queue:

- **event-batcher** decides *when* and *how many* events to send together
- **retry-queue** decides *what happens when delivery fails*

## Applicability

`both` — both client and server SDKs batch events, although the batching mechanisms differ by runtime and transport.

## Public signature(s)

No single public API.

Canonical internal operations look like:

```ts
enqueue(event): void | boolean
flush(): Promise<void> | void
shouldFlushNow(count): boolean
nextBatch(maxBatchSize): Event[]
startFlushTimer(): void
```

## Behavior

1. **Accept events one at a time from producers.** `capture`, `identify`, `alias`, and related APIs feed single events into the batcher/queue.
2. **Accumulate pending events.** Events remain buffered until one of the flush conditions is met.
3. **Trigger flush by threshold.** If the buffered count reaches `flushAt`, the batcher schedules or performs a flush.
4. **Trigger flush by timer.** If the threshold is not met quickly, a periodic timer / interval flush sends pending events after `flushInterval`.
5. **Cap each outgoing batch.** A flush may send only up to `maxBatchSize` items at once, leaving remaining queued events for subsequent batches.
6. **Preserve FIFO batch slicing.** Batches are typically taken from the front of the queue in arrival order.
7. **Respect request-size constraints where implemented.** Some SDKs also stop building a batch once the serialized size approaches a limit, even if the item count limit has not been reached.
8. **Allow explicit flushes.** Public `flush()` or shutdown paths bypass the normal timer/threshold waiting and drain what is pending.
9. **Run on background workers/timers where appropriate.** Native/server SDKs commonly use dedicated threads, executors, coroutines, or async handlers to batch without blocking callers.
10. **Allow wrapper SDKs to delegate batching to an underlying platform SDK instead of owning a second batcher.** Flutter exposes batching knobs like `flushAt`, `maxQueueSize`, `maxBatchSize`, and `flushInterval`, forwards them to the native mobile SDKs during setup, and otherwise delegates event batching to the underlying native/browser implementation.
11. **Adapt batch size when necessary.** Some SDKs reduce effective batch size after oversized-payload errors (`413`) so future flushes use smaller chunks.

## State & lifecycle

### State read

- queued/pending events
- `flushAt`
- `flushInterval`
- `maxBatchSize`
- optional size limits / current serialized batch size
- timer/worker running state

### State written

- queued/pending events
- active flush timer / scheduled work state
- adjusted batch size in SDKs that shrink after `413`
- worker/channel state in async batch handlers

### Lifecycle behavior

- Batching starts during SDK initialization when the queue/worker is created.
- Flush timers or background workers run while the SDK is active.
- Explicit flush and shutdown paths drain pending items outside the normal cadence.
- Some SDKs stop timers/workers during shutdown but still perform a final flush.
- Wrapper SDKs may only configure batching at setup time. Flutter Web, for example, attaches to an already-initialized browser SDK rather than applying its Dart batching config directly through the wrapper.

## Error handling

- Batch construction itself should not throw in normal operation.
- Individual oversized or corrupt events may be dropped/skipped before upload in some SDKs.
- Upload failures are handed off to retry logic rather than being handled by the batcher itself.
- If the queue is full before batching, events may be dropped according to the surrounding queue policy.

## Concurrency & ordering guarantees

- Producers may enqueue concurrently while a flush is in progress; synchronization is handled by locks, channels, executor serialization, or the JS event loop.
- Batches are generally constructed in FIFO order from queued events.
- Multiple flush triggers (threshold + timer + explicit flush) are commonly deduplicated so only one flush runs at a time.
- Ordering across distinct batches is best-effort; once events are split into different requests, retry timing can reorder their eventual arrival.

## Interactions

- **retry-queue** — consumes the batches produced by this component and handles retry/drop semantics after failed uploads.
- **http-client** — sends the actual batch payloads constructed by the batcher.
- **persistent-storage** — may back the pending event queue that the batcher slices into batches.
- **shutdown/flush** — forces the batcher to drain immediately.
- **wrapper setup/config** — Flutter's config object acts as a pass-through surface for native batching settings rather than implementing a separate Dart batch queue.

## Requirements

### Requirement: Canonical event-batcher behavior

The SDK SHALL implement the canonical `event-batcher` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Batcher flushes when batch size threshold is reached
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and flush at is 2
- **WHEN** capture is called with event "First"
- **AND** capture is called with event "Second"
- **THEN** the mock server should receive a batch containing events:
  | event  |
  | First  |
  | Second |
- **AND** the event queue should be empty after a successful flush

#### Scenario: Batcher flushes when interval elapses
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and flush interval is "10 seconds"
- **WHEN** capture is called with event "Delayed"
- **AND** the SDK clock advances by "10 seconds"
- **THEN** the mock server should receive a batch containing events:
  | event   |
  | Delayed |

#### Scenario: Batcher preserves FIFO order within a batch
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and flush at is 3
- **WHEN** capture is called with event "First"
- **AND** capture is called with event "Second"
- **AND** capture is called with event "Third"
- **THEN** the mock server should receive events in order:
  | event  |
  | First  |
  | Second |
  | Third  |
