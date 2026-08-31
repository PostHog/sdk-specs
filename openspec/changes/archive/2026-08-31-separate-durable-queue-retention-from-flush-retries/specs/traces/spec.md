## MODIFIED Requirements

### Requirement: Error handling and retries

The SDK SHALL handle export results as: 2xx → remove the exact acknowledged batch and reset
backoff; **413** → halve the batch and retry the same spans, dropping a single-span batch with a
warning; after a 413 shrink the SDK SHOULD ramp the batch size back up (+1 per healthy send)
toward the configured max; `408`/`429`/`5xx`/network error → retriable: keep the spans and retry
with exponential backoff capped at ~30s, floored by `Retry-After` when present; other `4xx`
(notably `400` and `401`) → non-retriable: drop the affected batch so a poison batch or bad key
cannot wedge the queue.

New spans SHALL continue to enqueue during backoff, subject to `maxQueueSize`. After a bounded,
documented number of retries on the same batch, the SDK SHALL end the active failure-driven
sequence. The canonical in-memory span queue SHALL drop that batch and resume with the next batch.
A port with a documented bounded durable queue deviation MUST instead retain the batch for a later
independent flush trigger. 413 shrink-and-resend cycles do not consume the retry budget because
halving is self-bounded (log₂ of the batch size). Successful acknowledgement MUST NOT remove spans
accepted into a full queue while the acknowledged request was in flight.

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
- **GIVEN** a 50-span batch returns 413
- **WHEN** the SDK retries
- **THEN** it resends the same spans in batches of ~25

#### Scenario: 400 is poison, not retried
- **WHEN** a batch returns 400
- **THEN** the SDK drops the batch and does not retry it

#### Scenario: retries are bounded for the canonical in-memory queue
- **GIVEN** a batch has failed with 500 the documented maximum number of times
- **WHEN** the final failure-driven retry fails
- **THEN** the SDK drops that batch and resumes normal sending with the next batch

#### Scenario: retry exhaustion preserves a durable trace queue deviation
- **GIVEN** a port documents a bounded durable trace queue
- **AND** a batch has failed with 500 the documented maximum number of times
- **WHEN** the final failure-driven retry fails
- **THEN** the active retry sequence ends
- **AND** the batch remains queued for a later independent flush trigger

#### Scenario: enqueue continues during backoff
- **GIVEN** exports are backing off after a 500
- **WHEN** spans end
- **THEN** they still enqueue (up to `maxQueueSize`) for the next attempt

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
