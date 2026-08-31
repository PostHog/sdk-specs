## MODIFIED Requirements

### Requirement: Error handling and retries

The SDK SHALL handle send results as: 2xx → remove the exact acknowledged batch and reset retry
state; **413** → halve the per-request batch size and retry the same records, and if the batch was
already a single record, drop it with a warning; `408`/`429`/`5xx`/network error → retriable, keep
records and retry later; other `4xx` → non-retriable, drop the affected batch so it cannot block
the queue. After a 413 shrink, the SDK SHOULD ramp the batch size back up (+1 per healthy send)
toward the configured max.

Between retries the SDK SHALL pause sends while continuing to accept new `captureLog` enqueues,
using the canonical backoff of exponential backoff capped at ~30s, floored by `Retry-After` when
present. After `maxRetries` on the same batch, the SDK SHALL end the active failure-driven
sequence. A bounded durable queue MUST retain the affected records for a later independent flush
trigger; the documented in-memory-only web buffer MAY drop them according to its page-lifetime
policy. Offline records SHALL remain persisted and become eligible on the next timer tick or
reconnect. Successful acknowledgement MUST NOT remove records accepted into a full queue while
the acknowledged request was in flight.

`Retry-After` is a **floor on the wait, not a replacement for the backoff**, and the documented
maximum bounds the header rather than the result. The wait SHALL be
`max(ownBackoff, min(parsedRetryAfter, documentedMaximum))`, evaluated in that order — clamp the
header first, then take the longer of it and the SDK's own next backoff delay. Taking the header
literally would let a `Retry-After: 1` pull a queue that had already backed off to 30s into an
aggressive one-second retry cadence; HTTP semantics are "not before this", which the longer of the
two satisfies in both directions. Clamping the header rather than the result is what keeps the
SDK's own backoff — which the caller configured — from being truncated by the bound.

The SDK SHALL parse **both** wire forms — delta-seconds and HTTP-date. A value it cannot parse, an
HTTP-date already in the past, or a non-positive delta SHALL be treated as absent, leaving the
SDK's own backoff, never zero. The documented maximum exists because nothing upstream bounds this
header, and an unbounded value from a misconfigured proxy would strand a queue indefinitely. Its
value is per-SDK — a short-lived process (serverless, a mobile background window) is served by a
tighter bound than a long-running one — and SHOULD fall between the ~30s backoff ceiling and five
minutes.

Where an SDK exempts a caller-driven flush from the wait — an explicit `flush()`, or a host
keep-alive drain that has no later attempt — it SHALL NOT charge the resulting refusal against the
batch's retry budget, so honoring the endpoint costs a request rather than the batch.

A reconnect signal SHALL NOT end an open `Retry-After` window. Connectivity returning says nothing
about the rate limit the endpoint set, and platforms fire it on every network handover.

This policy is stated in the same words in the `logs` and `traces` capabilities, for the same
reasons; the two SHALL NOT diverge.

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
- **THEN** the SDK drops the affected batch rather than retrying forever

#### Scenario: enqueue continues during backoff
- **GIVEN** the queue is paused for retry backoff
- **WHEN** a new log is captured
- **THEN** it is still persisted to the queue

#### Scenario: retry exhaustion preserves durable logs
- **GIVEN** a bounded durable log queue whose active retry sequence has reached its retry budget
- **WHEN** the final attempt fails with HTTP 503
- **THEN** the affected logs remain queued for a later independent flush trigger

#### Scenario: Retry-After never shortens the backoff
- **GIVEN** a queue that has backed off to 30s after repeated failures
- **WHEN** the next refusal carries `Retry-After: 1`
- **THEN** the SDK still waits 30s, not 1s

#### Scenario: a Retry-After within the maximum lengthens the backoff
- **GIVEN** a queue whose next backoff delay is 10s and whose documented maximum is 60s
- **WHEN** a refusal carries `Retry-After: 30`
- **THEN** the SDK waits 30s

#### Scenario: an oversized Retry-After is clamped, then floored
- **GIVEN** a queue whose next backoff delay is 10s and whose documented maximum is 60s
- **WHEN** a refusal carries `Retry-After: 3600`
- **THEN** the SDK waits 60s — the header clamped to the maximum, which is still the longer of the
  two

#### Scenario: HTTP-date form is honored
- **GIVEN** a queue whose next backoff delay is 10s and whose documented maximum is 60s
- **WHEN** a refusal carries a `Retry-After` HTTP-date 30 seconds in the future
- **THEN** the SDK waits until that instant

#### Scenario: an HTTP-date already in the past is treated as absent
- **WHEN** a refusal carries `Retry-After: Wed, 21 Oct 2015 07:28:00 GMT`
- **THEN** the SDK waits its own backoff, not zero

#### Scenario: unparseable Retry-After falls back to the backoff
- **WHEN** a refusal carries `Retry-After: 10 minutes`
- **THEN** the SDK ignores the header and uses its own backoff, rather than retrying immediately

#### Scenario: reconnect does not end the window
- **GIVEN** an open `Retry-After` window
- **WHEN** the platform reports connectivity restored
- **THEN** the SDK clears its failure backoff but still waits the window out before sending
