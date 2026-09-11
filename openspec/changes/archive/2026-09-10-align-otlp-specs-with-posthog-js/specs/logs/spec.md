## MODIFIED Requirements

### Requirement: Attribute value encoding

Every attribute value and the `body` SHALL be encoded as an OTLP `AnyValue` by runtime type: string
→ `stringValue`; boolean → `boolValue`; integer → `intValue` as a **stringified int64**;
float/double → `doubleValue`; non-finite float (`NaN`/`±Inf`) → `stringValue` ("NaN"/"Infinity"/
"-Infinity"); array → `arrayValue` (recursive); map/object → `kvlistValue` (recursive). A `null` or
`undefined` value SHALL cause the entire key to be omitted. So SHALL an empty key, with a debug
warning — OTLP requires a non-empty key, and the service stores one verbatim as a nameless attribute
nothing can filter on. The canonical integer encoding is the stringified form even though the server
also accepts a JSON number.

#### Scenario: integer encoded as string
- **WHEN** an attribute value is the integer 4999
- **THEN** it is encoded as `{ "intValue": "4999" }`

#### Scenario: nested object as kvlistValue
- **WHEN** an attribute value is `{ inner: 1 }`
- **THEN** it is encoded as `{ "kvlistValue": { "values": [ { "key": "inner", "value": { "intValue": "1" } } ] } }`

#### Scenario: non-finite number as string
- **WHEN** an attribute value is `NaN`
- **THEN** it is encoded as `{ "stringValue": "NaN" }`

#### Scenario: null value drops the key
- **WHEN** an attribute value is `null`
- **THEN** that attribute key does not appear in the record

#### Scenario: empty key dropped
- **WHEN** an attribute has the key `""`
- **THEN** that key does not appear in the record and the log is still sent

### Requirement: Resource and scope

The OTLP envelope SHALL carry **resource** attributes describing the producing service
(`service.name`, optional `service.version`, optional `deployment.environment`,
`telemetry.sdk.name`, `telemetry.sdk.version`, `os.name`, `os.version`) plus any user-supplied
`resourceAttributes`, and a **scope** of `{ name, version }` identifying the SDK. On key collision,
SDK-managed identity keys (`service.*`, `telemetry.sdk.*`) SHALL win over user `resourceAttributes`
so users cannot clobber identity keys. The SDK SHALL emit `telemetry.sdk.name` and
`telemetry.sdk.version`, and SHALL always emit `service.name` — even when a `resourceAttributes`
value is too large to encode in full: the SDK-set identity keys are encoded on a budget of their
own, after the user's attributes, so a user value that exhausts the encoder's traversal budget
cannot cost the resource its `service.name`.

#### Scenario: SDK identity keys protected
- **WHEN** a user sets `resourceAttributes: { "service.name": "evil" }` and the SDK resolves `service.name` to "checkout"
- **THEN** the emitted `service.name` is "checkout"

#### Scenario: scope identifies the SDK
- **WHEN** an iOS SDK at version 3.58.0 builds a payload
- **THEN** the scope is `{ "name": "posthog-ios", "version": "3.58.0" }`

#### Scenario: an oversized resource attribute does not cost service.name
- **GIVEN** `resourceAttributes` holding a value too large for the encoder to walk in full
- **WHEN** the envelope is built
- **THEN** it still carries `service.name` and `telemetry.sdk.*`

### Requirement: Batch assembly and concurrency

For a persistent queue the SDK SHALL take up to **max records per POST** from the head of the queue,
build one OTLP payload, POST it, and on success remove those records, repeating until the queue is
drained or a send fails. The per-POST cap SHALL keep each body comfortably under the service's 2 MiB
default limit, which a self-hosted deployment may keep; PostHog's hosted ingestion runs 10 MiB. The
SDK SHALL allow only **one flush in flight** at a time (joining or no-opping a concurrent flush
rather than double-sending), run logs on a worker/queue separate from the analytics-events pipeline,
and bound the drain loop by the queue length captured at flush start. `captureLog` SHALL be safe to
call from any thread.

#### Scenario: single flight
- **GIVEN** a flush already in progress
- **WHEN** a second flush is triggered
- **THEN** it joins or no-ops rather than re-sending the head of the queue

#### Scenario: bounded drain
- **GIVEN** records are enqueued during an active flush
- **WHEN** the drain loop runs
- **THEN** records added mid-flush are left for the next cycle

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
about the rate limit the endpoint set, and platforms fire it on every network handover. Nor SHALL
the retry budget running out: that is a verdict on the batch, not on the endpoint's rate limit.

The SDK SHOULD jitter each backoff delay, so clients refused together do not return together. The
`Retry-After` floor applies to the jittered delay.

A refusal arriving while a window is still open SHALL extend the deadline when it names a later
one, and SHALL NOT pull it in — a shorter header cannot cut a wait the endpoint has already asked
for. The extension SHALL be bounded by the documented maximum measured from the moment the window
was **first installed**, so repeated refusals cannot hold a window open indefinitely. On reaching
that ceiling the window closes, the next attempt goes out, and a further refusal installs a new
window. Without the bound, a host refused faster than the window is long refreshes the deadline
forever, and every path gated on the window being closed — the `logs` size and reconnect triggers,
the `metrics` timer re-arm — stays suppressed for as long as that host keeps flushing.

This bound is a deliberate divergence from OTLP, which asks for the header to be honored and names
no ceiling: a wait longer than the documented maximum is served short, so the SDK may retry before
a newer `Retry-After` has expired. It is the choice that fails toward keeping records rather than
toward an idle queue. Should the ingestion service begin issuing `Retry-After` itself — no signal
does today, so every header an SDK sees comes from a proxy, CDN or load balancer in front of it —
this SHOULD be revisited in favour of honoring the header literally.

The `408`/`5xx` half of that retriable set is a deliberate divergence from OTLP, which permits
retries only for `429`, `502`, `503` and `504` and forbids retrying other `4xx`/`5xx`. PostHog
ingestion returns transient `500`s that are worth retrying, and in SDKs where this predicate is
shared with the analytics-events transport, narrowing it would drop events on a path that is
working. Narrowing the set SHALL NOT happen before the ingestion team states which `5xx` responses
are transient.

This policy is stated in the same words in the `logs` and `traces` capabilities, for the same
reasons; the two SHALL NOT diverge.

#### Scenario: a longer Retry-After mid-window extends the deadline
- **GIVEN** an open window with 40s remaining and a documented maximum of five minutes
- **WHEN** a further refusal arrives naming `Retry-After: 120`
- **THEN** the SDK waits 120s from that refusal, not the 40s that remained

#### Scenario: a shorter Retry-After mid-window does not cut the wait
- **GIVEN** an open window with 110s remaining
- **WHEN** a further refusal arrives naming `Retry-After: 5`
- **THEN** the SDK still waits the 110s already asked for

#### Scenario: repeated refusals cannot hold the window open past the ceiling
- **GIVEN** a window installed five minutes ago against a documented maximum of five minutes
- **WHEN** a further refusal arrives naming `Retry-After: 240`
- **THEN** the window is closed, the next attempt goes out, and that refusal installs a new window

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

### Requirement: Server-side contract

The SDK SHALL design to the ingestion service's observed contract: a request body limit set per
deployment — 2 MiB by default (`MAX_REQUEST_BODY_SIZE_BYTES`), 10 MiB on PostHog's hosted US and EU
ingestion (verified 2026-09-10) — (exceed → 413) with **no** separate per-record size cap; success
is 200 with body `{}`; the service emits only 200/400/401/500 and **never** `429`, `Retry-After`, or
`quota_limited` (any 429 a client sees comes from shared infra); the server may re-derive severity,
clamp timestamps to ±24h of receive time (replacing out-of-range values with now and preserving the
original in `$originalTimestamp`), overwrite `observedTimeUnixNano`, zero `traceId`/`spanId` that
are not exactly 16/8 bytes, and flatten scope to `"{name}@{version}"`. The service accepts JSON or
protobuf, content-sniffed; SDKs SHALL send JSON.

#### Scenario: oversize body
- **WHEN** a request body exceeds the deployment's limit (10 MiB on PostHog's hosted ingestion)
- **THEN** the server responds 413 and the SDK applies the 413 batch-shrink path

#### Scenario: no quota signal from logs service
- **WHEN** the SDK handles responses
- **THEN** it does not depend on `429`/`Retry-After`/`quota_limited` from the logs endpoint

#### Scenario: invalid trace id zeroed
- **WHEN** a record sends a `traceId` that is not 16 bytes
- **THEN** the server zeroes it rather than rejecting the record
