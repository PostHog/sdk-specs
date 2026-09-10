## MODIFIED Requirements

### Requirement: Active span context and parenting

The SDK SHALL track an **active span** so spans nest without manual parent plumbing: a new
span's parent defaults to the active span at start time. Only scoped helpers activate a span,
for the duration of their callback (on context-manager platforms, entering the handle is the
scoped form); a manually created span is never made active implicitly.
The SDK SHALL expose `getActiveSpan()`, returning the active span handle or the platform's
null value when none is active. In a process running multiple SDK instances, the active-span
context SHALL be scoped per instance. Other PostHog pipelines in the same SDK SHOULD consume
the active context: a `captureLog` or `captureException` issued while a span is active SHOULD
carry that span's trace and span ids.

The propagation mechanism is platform-appropriate and its limits are an allowed, documented
variation: Python SHALL use `contextvars`; Node SHOULD use `AsyncLocalStorage`; the browser — and a
server runtime without an async-context primitive, such as an edge runtime — MAY be limited to
synchronous scoping (no async continuation tracking), in which case SDK documentation SHALL name an
explicit `parent` as the way to nest a span across an `await`; mobile ports SHOULD use their
structured-concurrency context primitive (coroutine context on Android, task-local values on Swift)
with a thread-local fallback. Platforms without an ambient context primitive (e.g. Go) MAY surface
the active span as an explicit context value instead — the scoped helper passes a derived context to
its callback, and `startSpan`/`getActiveSpan` accept a context argument — provided
default-parenting, helper-only activation, and null-when-absent semantics are preserved.

#### Scenario: default parenting from active span
- **GIVEN** `withSpan("parent", fn)` is executing
- **WHEN** `fn` calls `startSpan("child")` with no explicit parent
- **THEN** "child" is parented to "parent"

#### Scenario: manual spans do not activate
- **GIVEN** a span M created via `startSpan` and not yet ended
- **WHEN** another span starts with no explicit parent
- **THEN** its parent is the active span (or none), not M
- **AND** `getActiveSpan()` does not return M

#### Scenario: explicit parent overrides active span
- **GIVEN** an active span A and a handle for span B
- **WHEN** a span starts with `parent` set to B
- **THEN** it is parented to B, not A

#### Scenario: no active span reads as null
- **WHEN** `getActiveSpan()` is called outside any scoped helper
- **THEN** it returns the platform's null value

#### Scenario: logs correlate with the active span
- **GIVEN** a span is active with trace id T and span id S
- **WHEN** the app calls `captureLog({ body: "step done" })`
- **THEN** the log record carries `traceId` T and `spanId` S

#### Scenario: an edge runtime nests across an await only with an explicit parent
- **GIVEN** a runtime limited to synchronous scoping
- **WHEN** a `withSpan` callback awaits and then starts a span with no `parent`
- **THEN** that span starts a new trace
- **AND** a span started there with the callback's handle as `parent` is parented to it

### Requirement: Trace context interop

The SDK SHALL interoperate with W3C Trace Context using the traceparent string as the
interchange format. `span.traceparent()` produces the header value
`00-{trace-id}-{span-id}-{flags}`. For a span that starts a new trace the SDK SHALL set the
sampled bit (`01`), because it records every captured span. For a span continuing a remote
trace the SDK SHALL propagate the inbound sampled bit unchanged, including `00`: whether this
SDK records the span and what it tells the next hop are separate decisions, and overriding an
upstream head sampler's `00` makes a downstream parent-based sampler record a trace that was
already rejected. This is OpenTelemetry's `RECORD_ONLY` shape. Flag bits that version `00`
does not define SHALL be zeroed on emit rather than forwarded, as W3C requires of a vendor
that cannot interpret them.

Passing an incoming `traceparent` string as `parent` continues a remote trace: spans started
under it reuse the remote trace id and parent the remote span id, including when the incoming
flags are `00`. An accompanying `tracestate` value, passed via the `tracestate` option, SHALL
be preserved opaquely: emitted as the continued spans' `traceState` wire field, inherited by
their children, and returned by `span.tracestate()` for onward propagation next to the produced
`traceparent`. An invalid `traceparent` SHALL be ignored (fresh root context); an invalid `tracestate` SHALL be discarded without invalidating the `traceparent`.

Validity follows W3C Trace Context. Surrounding whitespace aside, every `traceparent` field is
lowercase hex: a header with uppercase ids or flags is invalid rather than folded, because a
conformant peer restarts the trace on it. Version `ff` is invalid. Version `00` is exactly
`version-traceid-parentid-flags`, so a version `00` header with anything appended is invalid, while
a higher version MAY carry further fields after a `-`. An all-zero trace id or span id is invalid. A
`tracestate` is valid when it is printable ASCII (plus HTAB), has at most 32 list members, and every
non-empty member contains a `=`. A valid `tracestate` longer than 512 characters SHALL be trimmed by
whole members rather than discarded — members over 128 characters first, then from the right — so
the entries nearest the caller survive. An SDK MAY also accept, as `parent`, the platform's
multi-value header form when it holds exactly one value (Node's `headersDistinct`). Automatic header
injection/extraction is out of scope for this capability and arrives with per-platform
instrumentation. This capability is distinct from the `tracing-headers` capability (`X-POSTHOG-*`
identity headers), which operates independently.

#### Scenario: continuing a remote trace
- **GIVEN** an incoming request with `traceparent` `00-<T>-<S>-01`
- **WHEN** the app passes that string as `parent` and starts a span
- **THEN** the span carries trace id T and `parentSpanId` S

#### Scenario: producing a traceparent
- **GIVEN** a span with trace id T and span id S that started its own trace
- **WHEN** the app calls `span.traceparent()`
- **THEN** it receives `00-<T>-<S>-01`

#### Scenario: a sampled-out trace is continued and propagated as sampled out
- **GIVEN** an incoming `traceparent` `00-<T>-<S>-00`
- **WHEN** the app passes it as `parent`, starts a span S2, and calls `traceparent()`
- **THEN** the span is still recorded and exported
- **AND** it receives `00-<T>-<S2>-00`, carrying the caller's decision onward

#### Scenario: undefined flag bits are not forwarded
- **GIVEN** an incoming `traceparent` `00-<T>-<S>-05`
- **WHEN** the app passes it as `parent`, starts a span S2, and calls `traceparent()`
- **THEN** it receives `00-<T>-<S2>-01` — the sampled bit kept, the undefined bit zeroed

#### Scenario: tracestate preserved opaquely
- **GIVEN** an incoming `traceparent` accompanied by `tracestate` `vendor=abc`
- **WHEN** the app passes both as `parent` and `tracestate` and starts a span
- **THEN** the span's record carries `traceState` `vendor=abc`
- **AND** `span.tracestate()` returns `vendor=abc` unchanged for onward propagation

#### Scenario: malformed traceparent ignored
- **WHEN** the app passes the string "garbage" as `parent`
- **THEN** the SDK starts a fresh root context and does not throw

#### Scenario: an uppercase traceparent restarts the trace
- **WHEN** the app passes `00-<T in uppercase hex>-<S>-01` as `parent`
- **THEN** the SDK starts a fresh root context rather than continuing trace T

#### Scenario: a version 00 traceparent with trailing fields is invalid
- **WHEN** the app passes `00-<T>-<S>-01-extra` as `parent`
- **THEN** the SDK starts a fresh root context

#### Scenario: a higher version may carry trailing fields
- **WHEN** the app passes `01-<T>-<S>-01-extra` as `parent`
- **THEN** the span continues trace T

#### Scenario: an over-long tracestate is trimmed by whole members
- **GIVEN** a valid 600-character `tracestate`, one of whose members is 150 characters long
- **WHEN** it accompanies a valid `traceparent`
- **THEN** that member is dropped and the remaining 449 characters are kept unchanged

#### Scenario: a tracestate with more than 32 members is discarded
- **WHEN** a `tracestate` with 33 members accompanies a valid `traceparent`
- **THEN** the `tracestate` is discarded and the trace is still continued

### Requirement: Span data model

Each ended span SHALL become one OTLP span record with: `traceId`, `spanId`, optional
`parentSpanId`, optional `traceState` (the continued context's tracestate string, omitted
when none); `name`; `kind` as the OTLP enum integer (unspecified 0, internal 1, server 2,
client 3, producer 4, consumer 5), defaulting to internal; `startTimeUnixNano` and
`endTimeUnixNano` as **string** nanosecond timestamps; `attributes`; zero or more `events`
(each with `name`, `timeUnixNano`, `attributes`); and `status` as `{ code, message? }` with
unset 0, ok 1, error 2 — omitted or 0 when never set. The wire `flags` field SHALL carry the
same W3C trace-flags byte the span propagates in its `traceparent` — the sampled bit set for a
trace the SDK started, the inbound bit for a continued one — so the record and the header
cannot disagree. SDKs SHOULD additionally set OpenTelemetry's has-is-remote mask (`0x100`) and,
when the parent came from an inbound header rather than a local handle, the is-remote mask
(`0x200`); this SDK always knows which, and a span exported without those bits can never be
backfilled with them. Bits above the OTLP masks SHALL remain zero. The server stores but does
not interpret `flags`.

`startTimeUnixNano` is captured at `startSpan` time unless the caller supplied `startTime`, which
wins. For spans started "now", the SDK SHOULD derive the end time — and each event's `timeUnixNano`
— from a monotonic clock elapsed since start, so durations survive wall-clock adjustments and event
timestamps land within the span window; where the platform distinguishes them, the clock SHALL be
one that advances during device sleep (Android `elapsedRealtime`, Swift `ContinuousClock`).
Backdated spans (explicit `startTime`) use wall clock. A span started under a local parent handle
that is not backdated SHOULD take its start on its root's clock basis — the root's wall-clock start
plus monotonic time elapsed since — rather than a fresh wall-clock reading, so every span in a local
trace shares one basis and a child cannot appear to start before or end after its parent through
clock rounding or a wall-clock step. The basis is per local trace rather than per process, since a
process-wide anchor drifts from the wall clock over a long uptime. Spans with a remote parent, a
backdated parent, or their own `startTime` keep their own reading. This goes beyond OpenTelemetry
JS, which anchors every span to its own wall-clock reading. `addEvent` MAY accept an explicit
timestamp. Span names SHALL be low-cardinality operation names (`GET /users/:id`, `db.query cart`);
variable values belong in attributes, never interpolated into the name — the product aggregates
operations by (service, name). Span links are reserved at the wire level and are not part of the v1
public API.

#### Scenario: default kind and unset status
- **WHEN** a span is started with no kind and ended with no status call
- **THEN** the record has kind 1 (internal) and no error status

#### Scenario: flags agree with the propagated header
- **GIVEN** a span continuing an inbound `traceparent` whose flags byte is `00`
- **WHEN** its record is built
- **THEN** the wire `flags` low byte is `0`, matching what `traceparent()` propagates

#### Scenario: parent remoteness is recorded
- **GIVEN** a span whose parent was supplied as a `traceparent` string
- **WHEN** its record is built
- **THEN** `flags` has both the has-is-remote (`0x100`) and is-remote (`0x200`) bits set
- **AND** a span whose parent was a local handle has `0x100` set and `0x200` clear

#### Scenario: timestamps are strings and ordered
- **WHEN** a span's record is built
- **THEN** `startTimeUnixNano` and `endTimeUnixNano` are string-encoded integers with
  end ≥ start
- **AND** end minus start reflects monotonic elapsed time where the platform has a monotonic
  clock

#### Scenario: event timestamp shares the span's clock basis
- **GIVEN** a span started at T1 whose platform has a monotonic clock
- **WHEN** `addEvent("cache miss")` is called mid-span and the wall clock jumps backward
  before `end()`
- **THEN** the event's `timeUnixNano` still falls between `startTimeUnixNano` and
  `endTimeUnixNano`

#### Scenario: variable data kept out of the name
- **WHEN** the SDK's own instrumentation records a request to `/users/123`
- **THEN** the span name is the route template (e.g. `GET /users/:id`) and `123` appears only
  as an attribute

#### Scenario: a child stays inside its parent's window
- **GIVEN** a span started when the millisecond wall clock read 1000 but true time was 1000.9, and a
  child started under it 0.1ms later
- **WHEN** the child ends 0.05ms of monotonic time before the parent does
- **THEN** the child's `endTimeUnixNano` is not after the parent's

#### Scenario: a wall-clock step does not move a child outside its parent
- **GIVEN** a running span, after which the wall clock steps back 500ms
- **WHEN** a child starts under it
- **THEN** the child's `startTimeUnixNano` is not before the parent's

### Requirement: Client-side validity

Because one malformed span rejects the entire request server-side, the SDK SHALL enqueue only
well-formed records, sanitizing at end time: ids well-formed per the identifier requirement; `name`
non-empty (an empty or non-string name at `startSpan` or `updateName` SHALL be replaced with
`unknown` plus a debug warning); every string on the wire — span and event names, the status
message, `traceState`, attribute keys and string values — well-formed Unicode, an unpaired UTF-16
surrogate replaced with U+FFFD, because the service's JSON decoder rejects the whole request on one;
timestamps within `[0, i64::MAX]` nanoseconds — OTLP declares the fields `fixed64` but the service
parses signed 64-bit, so a negative (pre-epoch) value is as invalid as an overflow — a `startTime`,
`endTime`, or event timestamp outside that range SHALL be replaced with the current time (for
`endTime`, the derived end); end-before-start SHALL be corrected to end = start. The SDK SHOULD warn
when a backdated `startTime` is more than 24 hours old, because the server clamps such timestamps to
receive time.

#### Scenario: invalid startTime replaced
- **WHEN** `startSpan("x", { startTime: <value beyond the i64 nanosecond range> })` is called
- **THEN** the record carries the current time instead and no request is poisoned

#### Scenario: end before start corrected
- **GIVEN** a backdated span whose computed end would precede its start
- **WHEN** the record is built
- **THEN** `endTimeUnixNano` equals `startTimeUnixNano` and the record is still exported

#### Scenario: deep backdating warns
- **WHEN** a span is started with `startTime` 48 hours in the past
- **THEN** the SDK emits a debug warning that the server will clamp the timestamp

#### Scenario: an unpaired surrogate does not poison the batch
- **WHEN** a span is named with a string containing an unpaired UTF-16 surrogate
- **THEN** the exported name carries U+FFFD in its place and the batch is accepted

### Requirement: Span limits

The SDK SHALL cap **user-supplied** per-span content at documented defaults matching
OpenTelemetry's: at most 128 attributes and 128 events per span, configurable. Each event's
attributes SHALL likewise be capped, at OpenTelemetry's per-event default of 128, with the excess
counted in that event's `droppedAttributesCount`; an SDK MAY keep this cap fixed rather than expose
a knob. SDK-managed auto-context keys are exempt from the attribute cap and SHALL never be evicted
by it — they are the product's join keys. On overflow the earliest-set entries win: excess additions
SHALL be dropped silently with the counts reported via `droppedAttributesCount` and
`droppedEventsCount`. The caps SHALL be re-applied after `beforeSpanSend` runs.

The SDK SHALL also bound the length of a single attribute value via `maxAttributeValueLength`,
applied to span attributes, event attributes, and resource attributes alike. The bound SHALL
reach every string the value contains, including strings nested inside arrays and maps, since
a value the caller nested is no smaller than one they did not. Traversal SHALL be bounded in
depth so a self-referencing value terminates, and a value the SDK cannot walk safely SHALL be
left as-is rather than throwing. Numbers and booleans are bounded already. Truncation SHALL be
silent and SHALL NOT count toward `droppedAttributesCount`, which counts whole entries.

The count caps alone do not bound a span: one multi-megabyte value takes the whole span past
the ingestion body limit, and the too-large path then drops that span entirely rather than
trimming it. Unlike the count caps, OpenTelemetry leaves its equivalent
(`attributeValueLengthLimit`) unlimited by default; SDKs SHALL choose a finite default and
document it.

#### Scenario: attribute overflow trimmed and counted
- **GIVEN** the attribute cap is 128
- **WHEN** a span accumulates 130 user attributes
- **THEN** the first 128 are exported and the record carries `droppedAttributesCount: 2`

#### Scenario: auto-context survives the cap
- **GIVEN** a span already at the user-attribute cap
- **WHEN** the record is built
- **THEN** `posthogDistinctId` and `sessionId` are still present

#### Scenario: long value truncated
- **GIVEN** `maxAttributeValueLength` is 8192
- **WHEN** a span sets an attribute to a 40000-character string
- **THEN** the exported value is 8192 characters and `droppedAttributesCount` is unchanged

#### Scenario: nested strings are bounded too
- **GIVEN** `maxAttributeValueLength` is 8192
- **WHEN** a span sets an attribute to `{ "body": <a 40000-character string> }`
- **THEN** the exported value's `body` is 8192 characters

#### Scenario: a self-referencing value terminates
- **WHEN** a span sets an attribute to a map that contains itself
- **THEN** the span is exported and the SDK does not throw or hang

#### Scenario: event attributes are capped
- **GIVEN** the per-event attribute cap is 128
- **WHEN** `addEvent("batch", <130 attributes>)` is called
- **THEN** the event carries the first 128 and `droppedAttributesCount: 2`

### Requirement: Attribute value encoding

Span, event, and resource attribute values SHALL use the same OTLP `AnyValue` encoding as the logs
capability: string → `stringValue`; boolean → `boolValue`; integer → `intValue` as a stringified
int64; float → `doubleValue`; non-finite float → `stringValue` ("NaN"/"Infinity"/"-Infinity"); array
→ `arrayValue`; map → `kvlistValue`; `null`/`undefined` SHALL drop the key, and so SHALL an empty
key, with a debug warning — OTLP requires a non-empty key, and the service stores one verbatim as a
nameless attribute nothing can filter on. An integer outside `[-2^63, 2^63-1]` (e.g. a Python or JS
bigint) SHALL be encoded as `stringValue` (its decimal string) with a debug warning — mirroring the
non-finite-float rule — never as `intValue`, which would 400 the entire batch. Because the ingestion
service flattens attribute values to strings for storage, SDKs SHOULD prefer primitive values and
SHOULD document that nested structures survive only as serialized strings.

#### Scenario: integer attribute stringified
- **WHEN** a span attribute value is the integer 42
- **THEN** the wire encoding is `{ "intValue": "42" }`

#### Scenario: null attribute dropped
- **WHEN** a span attribute value is `null`
- **THEN** the key is omitted from the record

#### Scenario: integer beyond int64 encoded as string
- **WHEN** a span attribute value is 2^64 (outside the int64 range)
- **THEN** the wire encoding is `{ "stringValue": "18446744073709551616" }`, not an
  `intValue`, and a debug warning is emitted

#### Scenario: empty key dropped
- **WHEN** a span attribute has the key `""`
- **THEN** the key is omitted from the record and the span is still exported

### Requirement: Resource and scope

The OTLP envelope SHALL carry resource attributes describing the producing service — `service.name`
(always emitted: the configured value, else `unknown_service`, the bare form of OpenTelemetry's
`unknown_service:<process>` convention, chosen for cross-platform consistency), optional
`service.version` and `deployment.environment`, `telemetry.sdk.name`, `telemetry.sdk.version`,
`os.name`, `os.version` — plus user-supplied `resourceAttributes`, with SDK-managed identity keys
(`service.*`, `telemetry.sdk.*`) winning on collision. The scope SHALL be `{ name, version }`
identifying the SDK; the server flattens it to `"{name}@{version}"`. The SDK SHALL always send
`service.name`: the server reads `service_name` only from that attribute and stores an empty string
when it is missing, leaving spans unattributable in the product. It SHALL do so even when a
`resourceAttributes` value is too large to encode in full: the SDK-set identity keys are encoded on
a budget of their own, after the user's attributes, so a user value that exhausts the encoder's
traversal budget cannot cost the resource its `service.name`.

#### Scenario: service name always present
- **WHEN** the app configures no `serviceName`
- **THEN** the resource carries `service.name` `unknown_service` rather than omitting the key

#### Scenario: identity keys protected
- **WHEN** `resourceAttributes` includes `telemetry.sdk.name: "custom"`
- **THEN** the emitted `telemetry.sdk.name` is the SDK's own identity

#### Scenario: an oversized resource attribute does not cost service.name
- **GIVEN** `resourceAttributes` holding a value too large for the encoder to walk in full
- **WHEN** the envelope is built
- **THEN** it still carries `service.name` and `telemetry.sdk.*`

### Requirement: Flush triggers

The SDK SHALL flush on each applicable trigger: (1) a repeating timer at `flushIntervalMs`; (2)
queue depth reaching `maxExportBatchSize`; (3) a manual `flush()` — the SDK's global `flush()` SHALL
drain the traces queue alongside events, logs, and replay; (4) the app entering background / the
platform lifecycle suspend (mobile ports), flushing before the OS suspends the process; (5) page
unload via a beacon-style send (web) — beacons cannot set headers and carry a small body budget (~64
KB), so the unload path SHALL use the `?token=` auth fallback with a raw (uncompressed) reduced
batch, and spans that do not fit remain queued and may be lost with the page; (6) network
connectivity being restored, where the platform exposes it; (7) on a host that offers a request
keep-alive primitive (a serverless `waitUntil`), a span ending SHALL register the drain with it, so
a handler that only records spans still holds its invocation open until they are sent. There is
deliberately no client-side rate cap (unlike logs): span volume is bounded by instrumentation, and
`maxQueueSize`, `maxLiveSpans`, and `beforeSpanSend` are the pressure valves.

#### Scenario: background flush
- **GIVEN** queued spans on a mobile app
- **WHEN** the app enters background
- **THEN** the SDK flushes before the OS suspends the process

#### Scenario: global flush includes traces
- **WHEN** the app calls the SDK's global `flush()`
- **THEN** the span queue is drained along with the other pipelines

#### Scenario: unload beacon fallback
- **GIVEN** a browser page unloading with queued spans
- **WHEN** the beacon send fires
- **THEN** it POSTs a raw JSON reduced batch to `{host}/i/v1/traces?token={projectApiKey}`
  with no custom headers

#### Scenario: a span-only serverless handler is held open
- **GIVEN** an SDK configured with a `waitUntil` keep-alive, in a handler that records spans but
  captures no events
- **WHEN** a span ends
- **THEN** the SDK registers a drain with `waitUntil`

### Requirement: Batch assembly and concurrency

Each POST SHALL carry at most `maxExportBatchSize` spans; the default SHALL be chosen so a full
batch sits comfortably under the service's 2 MiB default limit, which a self-hosted deployment may
keep. The reactive 413 path SHALL remain the overflow mechanism, since neither the SDK's batch-size
default nor any limit compiled into it is authoritative — a proxy in front of capture can lower the
limit and a self-hosted deployment can raise it. An SDK MAY additionally measure the assembled body
and report it as oversized without sending, when the measurement matches how the endpoint applies
its own limit: **on the uncompressed body**, since the endpoint decompresses before it measures, and
**in bytes** rather than in the platform's string units. The limit such a measurement uses SHALL be
the largest one a known deployment configures — 10 MiB, what PostHog's hosted ingestion runs — not
the service default: measuring against 2 MiB would refuse bodies the hosted endpoint accepts,
dropping spans with no `413` to show for them. Such a measurement SHALL feed the same
shrink-and-drop path a 413 does, so behavior is identical apart from the request not being spent.
Only one flush SHALL be in flight at a time, on a worker/queue separate from the analytics-events
pipeline; the drain loop is bounded by the queue length at flush start. Every export attempt SHALL
carry a finite deadline (request timeout); an attempt exceeding it counts as a network error —
retriable — and releases the single-flight slot, so a request that never settles cannot wedge the
pipeline. A flush trigger arriving during an active flush SHALL NOT be lost: it joins the active
flush and guarantees a follow-up drain pass covering spans enqueued after the active flush's
watermark — a trigger MAY no-op only when such a pass is already pending. All public tracing APIs
SHALL be safe to call from any thread.

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

### Requirement: Server-side contract

The SDK SHALL design to the ingestion service's observed contract. The request body limit is
deployment configuration, applied raw or after gzip decompression, and exceeding it returns 413: the
service defaults to 2 MiB (`MAX_REQUEST_BODY_SIZE_BYTES`), and PostHog's hosted US and EU ingestion
run 10 MiB (verified 2026-09-10 against both regions: a 9.9 MiB body is accepted, a 10.1 MiB one
refused). A request with no token at all returns 401, as does a manually-blocked token. A token
whose *shape* rules it out as a project API key (wrong prefix such as `phx_`, over 64 characters,
non-ASCII, empty) also returns 401: posthog/posthog#76501, split out of the abandoned #75090, landed
shared shape validation in the capture-logs authorizer on 2026-08-04, and the traces, logs and
metrics endpoints all run it. A **well-formed but unknown token is still accepted with 200**, and
that is the gap that matters: capture does not resolve tokens against projects (that would require
Postgres at the ingest edge), so a mistyped-but-plausible `phc_` key produces successful-looking
responses while every span is dropped downstream, and the SDK cannot detect this from responses. SDK
documentation SHALL NOT present a 2xx export as confirmation that tracing is correctly configured.
The body is decoded as OTLP protobuf first, then JSON (a single `ExportTraceServiceRequest` object
or JSONL lines merged); a body that decodes as neither returns 400. A span whose fields fail
decoding or row conversion — e.g. a timestamp that does not fit signed 64-bit nanoseconds — **400s
the entire request**, which is why the client-side validity requirement exists; note the distinction
between an *unrepresentable* timestamp (rejected) and a representable-but-stale one (clamped,
below). Success is 200 with body `{}`. The service emits only 200/400/401/413/500 and never
`429`/`Retry-After`/`quota_limited`. posthog/posthog#75090 would have added per-signal quota
enforcement at capture, giving an over-quota project **429 with `Retry-After`** before anything
reached Kafka, with logs, metrics and traces each on their own bucket; it was closed unmerged on
2026-08-17. Only its token-shape half was salvaged, as #76501 above; the quota half has no
replacement. So any `429` with a `Retry-After` that an SDK sees comes from shared infrastructure in
front of capture — a proxy, CDN or load balancer — which is also why the retry requirement bounds
how long the SDK will honor one. The SDK SHALL NOT *require* a quota signal, but SHALL honor `429` +
`Retry-After` when present — the retry requirement already does.

The server further: zeroes trace/span/parent ids that are not exactly 16/8 bytes; replaces a
zero start time with receive time; clamps representable timestamps outside ±24h of receive
time to now, preserving the original in `$originalTimestamp` (RFC3339); defaults a zero end
time to the (clamped) start time; sets its own observed timestamp; flattens attribute values
to strings; stores events and links as serialized JSON; flattens scope to
`"{name}@{version}"`; reads `service_name` only from the `service.name` resource attribute
(empty string when absent); and assigns each span a server-generated UUID. The downstream Kafka consumer reads a
`traces_mb_ingested` quota set after capture has returned 200 — a set nothing currently
populates (the billing `QuotaResource` enum has no traces entry), so the filter is inert today and
no replacement for #75090 has moved quota enforcement to capture. Under every one of these regimes
the SDK receives no per-request proof of ingestion and SHALL NOT treat a 200 as proof of
ingestion.

#### Scenario: oversize body
- **WHEN** a request body exceeds the deployment's limit (10 MiB on PostHog's hosted ingestion)
- **THEN** the server responds 413 and the SDK applies the batch-shrink path

#### Scenario: missing token is rejected
- **WHEN** a request reaches the service with neither an `Authorization` header nor a `token`
  parameter
- **THEN** the server responds 401 and the SDK treats the batch as non-retriable
  misconfiguration

#### Scenario: wrong token is not detectable
- **GIVEN** an SDK configured with a mistyped project API key
- **WHEN** it exports a batch
- **THEN** the server responds 200 and no spans reach the project

#### Scenario: whole batch rejected on one bad span
- **GIVEN** a batch where one span's timestamp does not fit signed 64-bit nanoseconds
- **WHEN** the batch is POSTed
- **THEN** the server responds 400 and every span in the request is lost

#### Scenario: stale timestamp clamped not dropped
- **WHEN** a span arrives with a representable start time 48h in the past
- **THEN** the server accepts it, stores the receive time, and keeps the original in
  `$originalTimestamp`

#### Scenario: no quota signal required
- **WHEN** the SDK handles export responses
- **THEN** it does not *require* `429`, `Retry-After`, or `quota_limited` from the traces
  endpoint to function correctly
- **AND** when a `429` with `Retry-After` does arrive, it backs off per the retry
  requirement rather than ignoring it
