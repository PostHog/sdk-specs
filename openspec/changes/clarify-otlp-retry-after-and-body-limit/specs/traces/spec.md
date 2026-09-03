## MODIFIED Requirements

### Requirement: Error handling and retries

The SDK SHALL handle export results as: 2xx → remove batch, reset backoff; **413** → halve
the batch and retry the same spans, dropping a single-span batch with a warning; after a 413
shrink the SDK SHOULD ramp the batch size back up (+1 per healthy send) toward the configured
max; `408`/`429`/`5xx`/network error → retriable: keep the spans and retry with exponential
backoff capped at ~30s, honoring `Retry-After` when present; other `4xx` (notably `400` and
`401`) → non-retriable: drop the batch so a poison batch or bad key cannot wedge the queue.
New spans SHALL continue to enqueue during backoff, subject to `maxQueueSize`. After a
bounded, documented number of retries on the same batch the SDK SHALL drop it. 413
shrink-and-resend cycles do not consume that retry budget — halving is self-bounded (log₂ of
the batch size); the budget applies to the retriable-failure path.

`Retry-After` is a **floor on the wait, not a replacement for the backoff**: the SDK SHALL wait
the longer of its own next backoff delay and the header. Taking the header literally would let a
`Retry-After: 1` pull a queue that had already backed off to 30s into a hot loop; HTTP semantics
are "not before this", which the longer of the two satisfies in both directions.

The SDK SHALL parse **both** wire forms — delta-seconds and HTTP-date. A value it cannot parse, a
date already in the past, or a non-positive delta SHALL fall back to the SDK's own backoff, never
to zero. The SDK SHALL clamp the parsed wait to a documented maximum: nothing upstream bounds this
header, and an unbounded value from a misconfigured proxy would strand a queue indefinitely. The
maximum is per-SDK — a short-lived process (serverless, a mobile background window) is served by a
tighter bound than a long-running one — and SHOULD fall between the ~30s backoff ceiling and five
minutes.

Where an SDK exempts a caller-driven flush from the wait — an explicit `flush()`, or a host
keep-alive drain that has no later attempt — it SHALL NOT charge the resulting refusal against the
batch's retry budget, so honoring the endpoint costs a request rather than the spans.

#### Scenario: 413 shrinks the batch
- **GIVEN** a 50-span batch returns 413
- **WHEN** the SDK retries
- **THEN** it resends the same spans in batches of ~25

#### Scenario: 400 is poison, not retried
- **WHEN** a batch returns 400
- **THEN** the SDK drops the batch and does not retry it

#### Scenario: retries are bounded
- **GIVEN** a batch that has failed with 500 the documented maximum number of times
- **WHEN** the final retry fails
- **THEN** the SDK drops the batch and resumes normal sending with the next batch

#### Scenario: enqueue continues during backoff
- **GIVEN** exports are backing off after a 500
- **WHEN** spans end
- **THEN** they still enqueue (up to `maxQueueSize`) for the next attempt

#### Scenario: Retry-After never shortens the backoff
- **GIVEN** a queue that has backed off to 30s after repeated failures
- **WHEN** the next refusal carries `Retry-After: 1`
- **THEN** the SDK still waits 30s, not 1s

#### Scenario: Retry-After lengthens the backoff
- **GIVEN** a queue whose next backoff delay is 10s
- **WHEN** a refusal carries `Retry-After: 120`
- **THEN** the SDK waits 120s

#### Scenario: HTTP-date form is honored
- **WHEN** a refusal carries `Retry-After: Wed, 21 Oct 2015 07:28:00 GMT`
- **THEN** the SDK waits until that instant, subject to the documented maximum

#### Scenario: unparseable Retry-After falls back to the backoff
- **WHEN** a refusal carries `Retry-After: 10 minutes`
- **THEN** the SDK ignores the header and uses its own backoff, rather than retrying immediately

#### Scenario: an oversized Retry-After is clamped
- **WHEN** a refusal carries a `Retry-After` beyond the SDK's documented maximum
- **THEN** the SDK waits the maximum and retries then

### Requirement: Batch assembly and concurrency

Each POST SHALL carry at most `maxExportBatchSize` spans; the default SHALL be chosen so a
full batch sits comfortably under the 2 MB server cap. The reactive 413 path SHALL remain the
overflow mechanism, since neither the SDK's batch-size default nor any limit compiled into it is
authoritative — a proxy in front of capture can lower the limit and a self-hosted deployment can
raise it. An SDK MAY additionally measure the assembled body and report it as oversized without
sending, when the measurement matches how the endpoint applies its own limit: **on the
uncompressed body**, since the endpoint decompresses before it measures, and **in bytes** rather
than in the platform's string units. Such a measurement SHALL feed the same shrink-and-drop path a
413 does, so behavior is identical apart from the request not being spent. Only one flush SHALL be
in flight at a time, on a worker/queue separate from the analytics-events pipeline; the drain loop
is bounded by the queue length at flush start. Every export attempt SHALL carry a finite
deadline (request timeout); an attempt exceeding it counts as a network error — retriable —
and releases the single-flight slot, so a request that never settles cannot wedge the
pipeline. A flush trigger arriving during an active flush SHALL NOT be lost: it joins the
active flush and guarantees a follow-up drain pass covering spans enqueued after the active
flush's watermark — a trigger MAY no-op only when such a pass is already pending. All public
tracing APIs SHALL be safe to call from any thread.

#### Scenario: single flight
- **GIVEN** a flush in progress
- **WHEN** a second flush triggers
- **THEN** it joins or no-ops rather than double-sending the queue head

#### Scenario: hung request cannot wedge the pipeline
- **GIVEN** an export request that never settles
- **WHEN** the attempt's deadline elapses
- **THEN** the attempt is treated as a retriable network error and the single-flight slot is
  released

#### Scenario: mid-flush trigger drains later spans
- **GIVEN** a flush in progress with watermark W
- **WHEN** a manual `flush()` arrives and spans enqueue after W
- **THEN** a follow-up drain pass covers the post-W spans before the joined flush is
  considered complete

#### Scenario: a body over the known cap is not sent
- **GIVEN** an SDK that measures the assembled body
- **WHEN** the uncompressed body exceeds the limit the SDK knows the endpoint applies
- **THEN** it takes the shrink-and-drop path without spending a request, and a single oversized
  span is dropped with the same warning a 413 would have produced

#### Scenario: the 413 path still applies below the SDK's own limit
- **GIVEN** a proxy that enforces a lower limit than the SDK knows about
- **WHEN** a body under the SDK's limit is refused with 413
- **THEN** the SDK halves and retries as it would without any local measurement
