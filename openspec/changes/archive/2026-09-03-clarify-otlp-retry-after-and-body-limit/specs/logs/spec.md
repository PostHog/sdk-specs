## MODIFIED Requirements

### Requirement: Error handling and retries

The SDK SHALL handle send results as: 2xx → remove batch, reset retry counter; **413** → halve the
per-request batch size and retry the same records, and if the batch was already a single record,
drop it with a warning; `408`/`429`/`5xx`/network error → retriable, keep records and retry later;
other `4xx` → non-retriable, drop the batch so it cannot block the queue. After a 413 shrink, the
SDK SHOULD ramp the batch size back up (+1 per healthy send) toward the configured max. Between
retries the SDK SHALL pause sends while continuing to accept new `captureLog` enqueues, using the
canonical backoff of exponential backoff capped at ~30s, floored by `Retry-After` when present.
After `maxRetries` on the same batch the SDK SHALL drop it. Offline records SHALL remain
persisted and retry on the next timer tick / reconnect.

`Retry-After` is a **floor on the wait, not a replacement for the backoff**: the SDK SHALL wait the
longer of its own next backoff delay and the header, SHALL parse both the delta-seconds and the
HTTP-date wire form, SHALL fall back to its own backoff (never to zero) on a value it cannot parse,
and SHALL clamp the wait to a documented maximum. This is the same rule the `traces` capability
states, for the same reasons; the two SHALL NOT diverge.

A reconnect signal SHALL NOT end an open `Retry-After` window. Connectivity returning says nothing
about the rate limit the endpoint set, and platforms fire it on every network handover.

#### Scenario: 413 shrinks the batch
- **GIVEN** a batch of 50 records returns 413
- **WHEN** the SDK retries
- **THEN** it retries the same records in batches of ~25

#### Scenario: single-record 413 is dropped
- **GIVEN** a single-record batch returns 413
- **WHEN** the SDK cannot split further
- **THEN** it drops that record and warns

#### Scenario: poison 4xx dropped
- **WHEN** a batch returns HTTP 400
- **THEN** the SDK drops the batch rather than retrying forever

#### Scenario: enqueue continues during backoff
- **GIVEN** the queue is paused for retry backoff
- **WHEN** a new log is captured
- **THEN** it is still persisted to the queue

#### Scenario: Retry-After never shortens the backoff
- **GIVEN** a queue that has backed off to 30s after repeated failures
- **WHEN** the next refusal carries `Retry-After: 1`
- **THEN** the SDK still waits 30s, not 1s

#### Scenario: reconnect does not end the window
- **GIVEN** an open `Retry-After` window
- **WHEN** the platform reports connectivity restored
- **THEN** the SDK clears its failure backoff but still waits the window out before sending
