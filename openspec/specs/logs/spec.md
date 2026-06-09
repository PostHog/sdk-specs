# Logs Specification

## Purpose

The logs capability lets an application emit **structured log records** through the PostHog SDK.
The SDK enriches each record with context (distinct id, session, feature flags, and platform
signals such as screen or URL), buffers it (persisted to durable storage where the platform
allows), and periodically **batches** and ships records to PostHog's ingestion endpoint as
**OpenTelemetry Logs (OTLP/HTTP) JSON**.

This spec is the platform-agnostic **contract** every PostHog SDK's logs implementation MUST
satisfy so that all SDKs stay on par. It is derived from the shipped Android, iOS, React Native,
and JavaScript/Web implementations plus the Rust `capture-logs` ingestion service. Each
behavior here is the **canonical** choice; where existing SDKs diverge, this spec states the
winner. Where a platform legitimately must deviate (lifecycle model, storage primitives, gzip
availability), the requirement notes the allowed variation explicitly.

Logs is a **separate pipeline** from analytics events (`capture`) and from session replay: its
own queue, its own endpoint (`/i/v1/logs`), and its own flush timer.

## Requirements

### Requirement: Public capture API

The SDK SHALL expose two equivalent entry points: a `captureLog` method accepting a `body`
(message string, required) plus optional `level`, `attributes`, `trace_id`, `span_id`, and
`trace_flags`; and a `logger` facade with one helper per severity (`trace`, `debug`, `info`,
`warn`, `error`, `fatal`), each taking `(body, attributes?)`. Both SHALL route through the same
capture path. A `captureLog` call with no `level` SHALL default to `info`.

#### Scenario: captureLog with explicit level
- **WHEN** the app calls `captureLog({ body: "checkout failed", level: "error" })`
- **THEN** one log record is enqueued with severityNumber 17 and body "checkout failed"

#### Scenario: logger helper delegates to captureLog
- **WHEN** the app calls `logger.info("ready", { region: "us" })`
- **THEN** the SDK enqueues a record equivalent to `captureLog({ body: "ready", level: "info", attributes: { region: "us" } })`

#### Scenario: missing level defaults to info
- **WHEN** the app calls `captureLog({ body: "hello" })` with no level
- **THEN** the record has severityNumber 9 (`INFO`)

#### Scenario: logger called before the SDK is ready
- **WHEN** a `logger` helper is called before the SDK has finished initializing
- **THEN** the call no-ops safely and does not throw

### Requirement: Capture-time gating

A `captureLog` call SHALL be **silently dropped** (never throwing) when any gate fails. The gates
SHALL be evaluated in this order: (1) SDK not enabled/initialized, (2) user opted out, (3) body
empty or whitespace-only, (4) `beforeSend` returned `null` or blanked the body, (5) rate cap for
the current window exceeded. There SHALL be no per-call "logs enabled" config flag and no remote
gate on `captureLog`.

#### Scenario: opted-out user drops the log
- **GIVEN** the user has opted out of capture
- **WHEN** `captureLog({ body: "x" })` is called
- **THEN** no record is enqueued and no error is thrown

#### Scenario: whitespace-only body is dropped
- **WHEN** `captureLog({ body: "   " })` is called
- **THEN** the body is treated as empty and the record is dropped

#### Scenario: gates short-circuit in order
- **GIVEN** the SDK is disabled
- **WHEN** `captureLog` is called
- **THEN** the SDK returns before evaluating `beforeSend` or the rate cap

### Requirement: Severity mapping

The SDK SHALL map the six levels to OpenTelemetry severity numbers exactly: `trace`=1, `debug`=5,
`info`=9, `warn`=13, `error`=17, `fatal`=21. An unknown or missing level SHALL map to `info` (9).
The SDK SHALL always send a positive `severityNumber`. The canonical `severityText` is UPPERCASE,
but casing is not significant for correctness because the server lowercases the text and recomputes
it from `severityNumber` whenever the number is greater than 0.

#### Scenario: each level maps to its number
- **WHEN** a `warn` log is captured
- **THEN** the record has severityNumber 13 and severityText "WARN"

#### Scenario: unknown level falls back to info
- **WHEN** a log is captured with a level the SDK does not recognize
- **THEN** the record has severityNumber 9 (`INFO`)

#### Scenario: severityNumber is authoritative
- **GIVEN** a record with severityNumber 17 and severityText "info"
- **WHEN** the server ingests it
- **THEN** the server derives the final text from the number (17 → "error") and the client text is ignored

### Requirement: Log record data model

Each queued log SHALL become one OTLP `logRecord` with: `timeUnixNano` and
`observedTimeUnixNano` as **string** nanosecond timestamps; `severityNumber`; `severityText`;
`body` wrapped as an OTLP `AnyValue`; `attributes` as an OTLP key/value list; and optional
`traceId`, `spanId`, and `flags`. `timeUnixNano` SHALL be captured at `captureLog` time (not flush
time). The client SHALL set `observedTimeUnixNano` equal to `timeUnixNano`. The `trace_flags`
input SHALL be emitted on the wire as `flags`. `traceId`/`spanId` SHALL be omitted when absent.

#### Scenario: timestamp captured at call time
- **GIVEN** a log captured at T1 and flushed at T2
- **WHEN** the OTLP record is built
- **THEN** `timeUnixNano` reflects T1, not T2

#### Scenario: trace_flags renamed to flags
- **WHEN** a log is captured with `trace_flags: 0` explicitly
- **THEN** the wire record includes `"flags": 0`
- **AND** when `trace_flags` is not provided, `flags` is omitted

#### Scenario: absent trace ids omitted
- **WHEN** a log is captured with no `trace_id`
- **THEN** the wire record omits the `traceId` field entirely

### Requirement: Monotonic capture timestamps

The SDK SHALL generate `timeUnixNano` as `current_unix_millis * 1_000_000`, emitted as a string.
The SDK SHOULD preserve strictly increasing timestamps for records emitted within the same
millisecond (e.g. a monotonic +1ns bump) so intra-millisecond ordering is retained.

#### Scenario: two logs in the same millisecond
- **WHEN** two logs are captured within the same wall-clock millisecond
- **THEN** the second record's `timeUnixNano` is strictly greater than the first

### Requirement: Attribute value encoding

Every attribute value and the `body` SHALL be encoded as an OTLP `AnyValue` by runtime type:
string → `stringValue`; boolean → `boolValue`; integer → `intValue` as a **stringified int64**;
float/double → `doubleValue`; non-finite float (`NaN`/`±Inf`) → `stringValue` ("NaN"/"Infinity"/
"-Infinity"); array → `arrayValue` (recursive); map/object → `kvlistValue` (recursive). A `null`
or `undefined` value SHALL cause the entire key to be omitted. The canonical integer encoding is
the stringified form even though the server also accepts a JSON number.

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

### Requirement: Auto-captured context attributes

At capture time the SDK SHALL enrich each record with available context, using these exact wire
keys: `posthogDistinctId`, `sessionId`, `feature_flags` (array of active flag keys), and the
platform-specific `screen.name` / `app.state` (mobile) or `url.full` (web). This context SHALL be
a snapshot frozen at capture time, not re-read at flush time. A key SHALL be omitted when its value
is absent or empty (no empty-string emission). On key collision, user-supplied `attributes` SHALL
win over auto-context.

#### Scenario: context snapshot is frozen at capture
- **GIVEN** a log captured while distinct id is "a"
- **WHEN** distinct id changes to "b" before the batch is sent
- **THEN** the record retains `posthogDistinctId` = "a"

#### Scenario: absent session id omits the key
- **WHEN** a log is captured with no active session
- **THEN** the record contains no `sessionId` attribute

#### Scenario: user attribute overrides auto-context
- **WHEN** a log supplies `attributes: { sessionId: "custom" }`
- **THEN** the record's `sessionId` is "custom"

### Requirement: Resource and scope

The OTLP envelope SHALL carry **resource** attributes describing the producing service
(`service.name`, optional `service.version`, optional `deployment.environment`,
`telemetry.sdk.name`, `telemetry.sdk.version`, `os.name`, `os.version`) plus any user-supplied
`resourceAttributes`, and a **scope** of `{ name, version }` identifying the SDK. On key collision,
SDK-managed identity keys (`service.*`, `telemetry.sdk.*`) SHALL win over user `resourceAttributes`
so users cannot clobber identity keys. The SDK SHALL emit `telemetry.sdk.name` and
`telemetry.sdk.version`.

#### Scenario: SDK identity keys protected
- **WHEN** a user sets `resourceAttributes: { "service.name": "evil" }` and the SDK resolves `service.name` to "checkout"
- **THEN** the emitted `service.name` is "checkout"

#### Scenario: scope identifies the SDK
- **WHEN** an iOS SDK at version 3.58.0 builds a payload
- **THEN** the scope is `{ "name": "posthog-ios", "version": "3.58.0" }`

### Requirement: HTTP transport

The SDK SHALL POST batches to `{host}/i/v1/logs?token={projectApiKey}`, where `host` is the
configured ingestion host with any trailing slash stripped and the token is URL-encoded in the
`token` query parameter. The request SHALL use method POST with `Content-Type: application/json`.
A successful response is HTTP 200 with body `{}`; the SDK SHALL treat any 2xx as success.

#### Scenario: endpoint and auth
- **WHEN** the SDK flushes with host `https://us.i.posthog.com` and key `phc_abc`
- **THEN** it POSTs to `https://us.i.posthog.com/i/v1/logs?token=phc_abc`

#### Scenario: success response
- **WHEN** the server returns HTTP 200 with body `{}`
- **THEN** the SDK removes the sent records from the queue

### Requirement: Payload envelope

A single batch SHALL produce exactly one `resourceLogs` entry containing exactly one `scopeLogs`
entry containing N `logRecords`.

#### Scenario: one batch one envelope
- **WHEN** a batch of 20 records is assembled
- **THEN** the payload has one `resourceLogs[0].scopeLogs[0].logRecords` array of length 20

### Requirement: Compression

The SDK SHALL gzip the JSON body by default and signal it either with a `Content-Encoding: gzip`
header on a gzipped body (preferred) or with a `?compression=gzip-js` / `?compression=gzip` query
parameter that the server translates into `Content-Encoding: gzip`. When gzip is unavailable on the
platform, the SDK SHALL send raw JSON with no `Content-Encoding`. There SHALL be no size threshold
for compression.

#### Scenario: gzipped with header
- **WHEN** a platform with gzip support flushes
- **THEN** the body is gzipped and sent with `Content-Encoding: gzip`

#### Scenario: gzip unavailable
- **GIVEN** a platform with no gzip primitive available
- **WHEN** the SDK flushes
- **THEN** it sends raw JSON with no `Content-Encoding` header

### Requirement: Configuration knobs

The SDK SHALL expose a `logs` configuration object with: flush interval, flush threshold, max
queue/buffer size, max records per POST, rate-cap max-logs, rate-cap window, `serviceName`,
`serviceVersion`, `environment`, `resourceAttributes`, and `beforeSend`. Defaults MAY differ by
platform (e.g. mobile uses a longer flush interval and tighter rate cap to respect cellular radio
and battery) but each SDK SHALL choose deliberate, documented defaults.

#### Scenario: per-platform defaults are deliberate
- **WHEN** a new SDK is implemented
- **THEN** it documents its chosen flush interval, buffer size, and rate cap rather than copying another platform's numbers blindly

### Requirement: Persistent queue

The SDK SHALL persist queued records to durable storage keyed per project so logs survive app
restarts/crashes (the in-memory-only web buffer is the documented exception for short-lived page
sessions). On overflow at `maxBufferSize` the SDK SHALL drop the **oldest** record(s) FIFO before
enqueuing the new one and log a warning. The SDK SHALL build the OTLP payload at flush time from
the persisted record. The logs queue SHALL be preserved across `reset()`.

#### Scenario: survives restart
- **GIVEN** records persisted to disk
- **WHEN** the app restarts before they were sent
- **THEN** the records are still present and eligible to flush

#### Scenario: overflow drops oldest
- **GIVEN** the queue is at `maxBufferSize`
- **WHEN** a new record is enqueued
- **THEN** the oldest record is dropped and a warning is logged

#### Scenario: reset preserves logs
- **WHEN** `reset()` is called
- **THEN** the persisted logs queue is retained

### Requirement: Startup and rehydration

On initialization the SDK SHALL load any previously-persisted records and resume sending them, SHALL
start the periodic flush timer, and SHALL register the lifecycle and (where the platform supports it)
network-reconnect observers used as flush triggers. The timer MAY be started eagerly at init or
armed lazily on first capture, provided persisted records still drain on the next flush trigger.

#### Scenario: persisted records resume on launch
- **GIVEN** records persisted from a prior session
- **WHEN** the SDK initializes
- **THEN** those records are rehydrated and sent on the next flush

### Requirement: Flush triggers

The SDK SHALL flush on each applicable trigger: (1) a repeating timer at the flush interval; (2)
queue depth reaching the flush threshold; (3) the app entering background/the platform lifecycle
suspend (mobile); (4) network connectivity being restored (where the platform exposes it); (5) a
manual public `flush()`; (6) page unload via a beacon-style send (web). The canonical manual flush
is a single unified `flush()` that drains all pipelines together (events, replay, and logs); any
global `flush()` SHALL include the logs queue and never silently skip it.

#### Scenario: timer flush ignores threshold
- **WHEN** the flush interval elapses with records below the threshold
- **THEN** the queued records are still flushed

#### Scenario: background flush
- **GIVEN** buffered logs on a mobile app
- **WHEN** the app enters background
- **THEN** the SDK flushes before the OS suspends the process

#### Scenario: global flush includes logs
- **WHEN** the app calls the SDK's global `flush()`
- **THEN** the logs queue is flushed along with events and replay

### Requirement: Shutdown flush

On SDK shutdown/close the SDK SHALL attempt a final flush of buffered logs bounded by a timeout, so
in-flight records are not lost when a process terminates.

#### Scenario: bounded final flush
- **WHEN** the SDK is shut down with buffered logs
- **THEN** it attempts to send them within a bounded time budget before stopping the timer

### Requirement: Batch assembly and concurrency

For a persistent queue the SDK SHALL take up to **max records per POST** from the head of the
queue, build one OTLP payload, POST it, and on success remove those records, repeating until the
queue is drained or a send fails. The per-POST cap SHALL keep each body comfortably under the 2 MB
server limit. The SDK SHALL allow only **one flush in flight** at a time (joining or no-opping a
concurrent flush rather than double-sending), run logs on a worker/queue separate from the
analytics-events pipeline, and bound the drain loop by the queue length captured at flush start.
`captureLog` SHALL be safe to call from any thread.

#### Scenario: single flight
- **GIVEN** a flush already in progress
- **WHEN** a second flush is triggered
- **THEN** it joins or no-ops rather than re-sending the head of the queue

#### Scenario: bounded drain
- **GIVEN** records are enqueued during an active flush
- **WHEN** the drain loop runs
- **THEN** records added mid-flush are left for the next cycle

### Requirement: Rate capping

The SDK SHALL apply a client-side tumbling-window rate cap: count logs accepted in the current
window and, once `maxLogs` is reached, **drop** subsequent logs (not buffer them) until the window
rolls over, emitting at most one warning per window. The cap SHALL run **after** `beforeSend` so
dropped records do not consume budget. A non-positive `maxLogs` or window SHALL disable the cap.
The SDK SHALL guard against the wall clock jumping backward by resetting the window.

#### Scenario: cap drops excess logs
- **GIVEN** `maxLogs` of 500 already reached in the current window
- **WHEN** a 501st log is captured
- **THEN** it is dropped and at most one warning has been emitted this window

#### Scenario: cap runs after beforeSend
- **GIVEN** a `beforeSend` that drops a record
- **WHEN** that record is processed
- **THEN** it does not count against the rate-cap budget

### Requirement: beforeSend hook

The SDK SHALL support an optional `beforeSend` hook to mutate or drop records before they are
queued, accepting either a single function or an array run left-to-right (each output feeding the
next). Returning `null`, or mutating the body to empty/whitespace, SHALL drop the record. A hook
that throws SHALL be caught: the SDK swallows the error and continues the chain with the prior
value. `beforeSend` SHALL run before the rate cap. (Web MAY omit `beforeSend` today; new SDKs SHALL
implement it.)

#### Scenario: hook drops record
- **WHEN** a `beforeSend` returns `null` for a record
- **THEN** the record is dropped and not enqueued

#### Scenario: throwing hook is contained
- **GIVEN** a `beforeSend` that throws
- **WHEN** a record is processed
- **THEN** the error is swallowed and the record continues with its pre-hook value

### Requirement: Error handling and retries

The SDK SHALL handle send results as: 2xx → remove batch, reset retry counter; **413** → halve the
per-request batch size and retry the same records, and if the batch was already a single record,
drop it with a warning; `408`/`429`/`5xx`/network error → retriable, keep records and retry later;
other `4xx` → non-retriable, drop the batch so it cannot block the queue. After a 413 shrink, the
SDK SHOULD ramp the batch size back up (+1 per healthy send) toward the configured max. Between
retries the SDK SHALL pause sends while continuing to accept new `captureLog` enqueues, using the
canonical backoff of honoring `Retry-After` when present and otherwise exponential backoff capped at
~30s. After `maxRetries` on the same batch the SDK SHALL drop it. Offline records SHALL remain
persisted and retry on the next timer tick / reconnect.

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

### Requirement: Remote config behavior

`captureLog` SHALL work whenever the SDK is initialized and not opted-out, regardless of remote
config. The remote `logs.captureConsoleLogs` flag SHALL gate only console-log **autocapture**
(mirroring `console.*` into logs), never the explicit `captureLog` API. There is no remote
kill-switch for the logs API today; the SDK SHALL NOT wait for a `logs.enabled`-style flag before
capturing.

#### Scenario: captureLog ignores remote config
- **GIVEN** remote config has not enabled `captureConsoleLogs`
- **WHEN** the app calls `captureLog`
- **THEN** the log is captured normally

#### Scenario: console autocapture gated by flag
- **WHEN** `logs.captureConsoleLogs` is false
- **THEN** the SDK does not mirror `console.*` calls into logs, but explicit `captureLog` still works

### Requirement: Server-side contract

The SDK SHALL design to the ingestion service's observed contract: a 2 MB request body cap (exceed
→ 413) with **no** separate per-record size cap; success is 200 with body `{}`; the service emits
only 200/400/401/500 and **never** `429`, `Retry-After`, or `quota_limited` (any 429 a client sees
comes from shared infra); the server may re-derive severity, clamp timestamps to ±24h of receive
time (replacing out-of-range values with now and preserving the original in `$originalTimestamp`),
overwrite `observedTimeUnixNano`, zero `traceId`/`spanId` that are not exactly 16/8 bytes, and
flatten scope to `"{name}@{version}"`. The service accepts JSON or protobuf, content-sniffed; SDKs
SHALL send JSON.

#### Scenario: oversize body
- **WHEN** a request body exceeds 2 MB
- **THEN** the server responds 413 and the SDK applies the 413 batch-shrink path

#### Scenario: no quota signal from logs service
- **WHEN** the SDK handles responses
- **THEN** it does not depend on `429`/`Retry-After`/`quota_limited` from the logs endpoint

#### Scenario: invalid trace id zeroed
- **WHEN** a record sends a `traceId` that is not 16 bytes
- **THEN** the server zeroes it rather than rejecting the record
