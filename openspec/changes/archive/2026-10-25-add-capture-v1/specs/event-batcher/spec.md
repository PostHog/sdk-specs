## Narrative alignment

When syncing this delta into the canonical `event-batcher` spec:

- In Behavior step 7, say that on capture v1 request-size limits are required, not optional: every lane is byte-aware with a target of at most 5 MiB of event bytes.
- In Behavior step 11 and the "adjusted batch size" State entry, mark batch-size adaptation after `413` as legacy behavior; on capture v1 `413` is terminal.
- In Error handling, say that on capture v1 the batcher drops no analytics event for size below capture's own per-event limit; only an event that cannot fit any request may be dropped locally.

## ADDED Requirements

### Requirement: Capture v1 batches are byte-aware and server SDKs never shrink them after a 413

An SDK that delivers events through capture v1 SHALL size each event by the bytes it will actually send (UTF-8 of the serialized event, exact or an upper bound, never a character count) and SHALL keep every analytics request at or under a byte target of at most 5 MiB of event bytes. The check SHALL run before appending: when the batch is non-empty and the next event would exceed the target, the batch is sent first and the event starts the next batch, so order is kept and an event larger than the target ships alone. The count thresholds (`flushAt`, `maxBatchSize`) still apply. Serializing each event once and building the body from those bytes is the preferred implementation; SDKs that already measure by a second serialization MAY keep it.

The SDK SHALL NOT impose a per-event analytics size cap below capture's own per-event limit (capture drops an event too large to store and reports it per event); an SDK MAY drop locally only an event larger than the request body limit, which capture can never accept. A `413` response SHALL be terminal on a server SDK: it SHALL NOT halve, split or resend the batch. A client SDK MAY halve a batch of more than one event on a `413` and resend it, as `retry-queue` allows; a `413` for a single event is terminal.

Legacy capture: several SDKs batched by count only, enforced per-event caps inherited from older forks (32 KB to 900 KB), and shrank the batch after a `413`.

#### Scenario: A batch closes before it would exceed the byte target (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture is called sequentially 3 times with an event named "big-{index}" whose serialized size is about 2 MiB
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** no received request body should exceed the SDK's byte target plus envelope overhead
- **AND** the events "big-0", "big-1" and "big-2" should have been received in that order across the requests

#### Scenario: An event larger than the target ships alone and in order (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture is called with distinct id "user-123" and event "small-before"
- **AND** capture is called with an event named "huge" whose serialized size is about 6 MiB
- **AND** capture is called with distinct id "user-123" and event "small-after"
- **AND** pending captures are flushed
- **THEN** exactly 3 capture request should have been received
- **AND** the second request should contain only the event "huge"
- **AND** the events should have been received in the order "small-before", "huge", "small-after"

#### Scenario: A 413 is terminal and the batch is not split (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **AND** the mock serves these ordered analytics responses:
  | status | body                               |
  | 413    | {"error":"payload_too_large"}      |
  | 200    | {"results":{"*":{"result":"ok"}}}  |
- **WHEN** capture is called with distinct id "user-123" and event "one"
- **AND** capture is called with distinct id "user-123" and event "two"
- **AND** pending captures are flushed
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** exactly 1 capture request should have been received
- **AND** the SDK should report the events "one" and "two" as not delivered with status 413
