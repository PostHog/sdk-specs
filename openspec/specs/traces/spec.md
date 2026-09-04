# Traces Specification

## Purpose

The traces capability lets an application create **spans** — timed operations with parentage —
through the PostHog SDK, so that distributed traces render as waterfalls in PostHog. The SDK
exposes a manual span API (`startSpan`) and a scoped helper (`withSpan`/context manager),
enriches each span with PostHog-native context (`posthogDistinctId`, `sessionId` — the
person/session/logs join keys), buffers finished spans in an in-memory queue, and **batches**
and ships them to PostHog's ingestion endpoint as **OpenTelemetry Traces (OTLP/HTTP) JSON**,
with no OpenTelemetry runtime dependency.

This spec is the platform-agnostic **contract** every PostHog SDK's tracing implementation MUST
satisfy so that all SDKs stay on par. Unlike most sibling specs it precedes the first SDK
implementation: it is derived from the Rust `capture-logs` ingestion service (verified
empirically against production on 2026-07-20), from the logs pipeline as the structural
template, and from W3C Trace Context for interop. Where a platform legitimately must deviate
(ambient-context availability, lifecycle model, sync/async helpers), the requirement notes the
allowed variation explicitly.

Traces is a **separate pipeline** from analytics events (`capture`), from logs, and from
session replay: its own queue, its own endpoint (`/i/v1/traces`), and its own flush triggers.
It is also distinct from the `tracing-headers` capability (which only propagates correlation
headers on outgoing requests without recording spans) and from LLM analytics traces (which are
captured as analytics events, not OTLP).
## Requirements
### Requirement: Public span API

The SDK SHALL expose two forms of span creation: the scoped helper (next requirement) as the
recommended primary form, and a manual form, `startSpan`, for spans that cannot wrap a
callback. `startSpan` accepts a `name` (string, required) plus optional `kind`, `attributes`,
`parent`, `tracestate`, and a caller-supplied `startTime` (platform-idiomatic time type, for
backdating), and returns a **span handle** that is not made active (see the active-span
requirement). `parent` SHALL accept either a span handle or a raw W3C `traceparent` string —
there is no separate span-context type; the traceparent string is the serialized context.
`tracestate` carries the incoming W3C `tracestate` string accompanying a `traceparent`-string
`parent` (ignored otherwise); a child created from a span-handle `parent` inherits that
span's tracestate. At the API
surface, `kind` SHALL use the string names (`internal`, `server`, `client`, `producer`,
`consumer`) and status the strings `ok` / `error`; the OTLP integer enums are a wire-level
concern. Field and method names are semantic: each SDK SHALL spell them per its platform
conventions (e.g. `start_span` in Python).

The handle SHALL support `setAttribute`/`setAttributes`, `addEvent(name, attributes?)`,
`setStatus(ok | error, message?)` (last-write-wins), `recordException(error)`,
`updateName(name)`, `traceparent()`, `tracestate()` (the span's tracestate string, or the
platform's null/empty value when none), and `end(endTime?)`. `updateName` SHALL replace the name
up until `end()` — the low-cardinality name is often only knowable after work begins (e.g. a
route template resolves mid-request). `end(endTime?)`'s optional caller-supplied end time
overrides the monotonic-derived end (backdating parity with `startTime`); an invalid or
out-of-range value SHALL fall back to the derived end time, and end-before-start is corrected
per the client-side validity requirement. `end()` SHALL be idempotent: a span produces at
most one record (exactly one when no gate drops it), and operations after the first `end()` —
including further `end()` calls — SHALL no-op with at most a debug warning.

#### Scenario: start and end produces one record
- **WHEN** the app calls `startSpan("checkout")` and later `end()` on the handle
- **THEN** exactly one span record named "checkout" is enqueued for export

#### Scenario: double end is idempotent
- **WHEN** `end()` is called twice on the same handle
- **THEN** exactly one record is enqueued
- **AND** the second call no-ops without error

#### Scenario: operations after end are ignored
- **GIVEN** a span whose `end()` was already called
- **WHEN** `setAttribute("k", "v")` is called on it
- **THEN** the exported record does not contain `k` and no error is thrown

#### Scenario: name updated after route resolution
- **GIVEN** a span started as "HTTP request" before routing
- **WHEN** `updateName("GET /users/:id")` is called before `end()`
- **THEN** the exported record's name is "GET /users/:id"

#### Scenario: explicit endTime overrides the derived end
- **GIVEN** a span backdated with an explicit `startTime`
- **WHEN** `end(endTime)` is called with a valid time after that start
- **THEN** `endTimeUnixNano` reflects the supplied `endTime`, not the monotonic-derived end

### Requirement: No-op span handles

Span-creating APIs SHALL return an inert span handle whenever tracing cannot run (traces not
configured, SDK not initialized, user opted out, live-span bound reached), supporting the full
handle surface so caller code never branches. An inert handle SHALL record nothing, SHALL
enqueue nothing, and SHALL NOT count toward the live-span bound.

There are two kinds of inert handle, distinguished only by whether the caller supplied usable
inbound trace context:

A **no-op handle** is returned when no valid inbound `traceparent` was supplied. It SHALL
never be activated, and a child started with it as `parent` SHALL itself be a no-op — never an
orphan with invented ids. `traceparent()` and `tracestate()` on a no-op handle SHALL return the
platform's null/empty value — never a well-formed header — so an id that was never recorded
cannot propagate. Scoped helpers still run their callback and return its value; because a no-op
is never activated, `getActiveSpan()` inside such a callback returns the null value — callback
code SHOULD use the handle it receives rather than re-reading the ambient context.

A **pass-through handle** is returned when the caller supplied a valid `traceparent` as
`parent`. It SHALL echo that inbound context: `traceparent()` returns the inbound header
value — preserving its version and flags byte exactly as received — and `tracestate()` returns
the accompanying `tracestate` when one was supplied and valid. Scoped helpers SHALL activate a
pass-through handle for the duration of the callback, so `getActiveSpan()?.traceparent()`
inside it propagates the trace onward. A child started with a pass-through handle as `parent`
SHALL itself be inert. This propagates only ids the upstream caller recorded; the SDK SHALL
NOT invent a trace id, span id, or flags byte for an inert handle.

This mirrors the OpenTelemetry API contract for an absent SDK, where the API returns a
non-recording span carrying the parent `SpanContext` so that a service which is not itself
tracing does not sever the chain.

#### Scenario: no-op span when opted out
- **GIVEN** the user has opted out of capture
- **WHEN** the app calls `startSpan("x")`
- **THEN** a no-op handle is returned, all its operations succeed silently, and nothing is
  enqueued

#### Scenario: child of a no-op is a no-op
- **GIVEN** a no-op handle N
- **WHEN** a span starts with `parent` set to N
- **THEN** the child is itself a no-op and nothing is enqueued for either

#### Scenario: no-op handle produces no traceparent
- **GIVEN** a no-op handle and no inbound trace context
- **WHEN** `traceparent()` is called
- **THEN** it returns the platform's null/empty value, not a well-formed header

#### Scenario: scoped helper still runs with tracing off
- **GIVEN** an SDK initialized with no `traces` config
- **WHEN** the app calls `withSpan("job", fn)` with no `parent`
- **THEN** `fn` runs exactly once with a no-op handle and its return value is returned
- **AND** `getActiveSpan()` inside `fn` returns the platform's null value

#### Scenario: pass-through handle forwards an inbound trace
- **GIVEN** an SDK initialized with no `traces` config
- **AND** an incoming request with `traceparent` `00-<T>-<S>-01`
- **WHEN** the app calls `startSpan("x", { parent })` with that string
- **THEN** an inert handle is returned, nothing is enqueued, and `traceparent()` returns
  `00-<T>-<S>-01` unchanged

#### Scenario: pass-through handle is activated by a scoped helper
- **GIVEN** an SDK initialized with no `traces` config
- **AND** an incoming `traceparent` `00-<T>-<S>-00` with `tracestate` `vendor=abc`
- **WHEN** the app calls `withSpan("job", { parent, tracestate }, fn)`
- **THEN** `getActiveSpan()` inside `fn` returns the pass-through handle
- **AND** its `traceparent()` returns `00-<T>-<S>-00` and its `tracestate()` returns
  `vendor=abc`
- **AND** nothing is enqueued

### Requirement: Scoped span helpers and exception recording

The SDK SHALL provide a scoped helper that runs a callback inside a span and guarantees the
span ends: in callback form (e.g. `withSpan(name, fn)` — `fn` receives the span handle) and,
where idiomatic, the platform's scoped construct (Python context manager and decorator).
Where the scoped construct is the context-manager/decorator protocol, the manual form MAY
double as the scoped form: the handle `start_span` returns activates only when entered
(`with`) or applied as a decorator — calling `start_span` without entering it remains the
manual, inactive form. The helper SHALL accept the same options as `startSpan`. While the
callback runs, the span SHALL be the active span.

The helper SHALL cover asynchronous callbacks with end-at-settle semantics: where the runtime
can detect an awaitable return (JS Promise, Python coroutine), the same helper handles both;
platforms whose type system distinguishes sync from async callbacks SHALL provide distinct
overloads (Kotlin `suspend`, Swift `async`) with identical semantics — on those platforms the
async overload is also what carries activation across suspension points.

If the callback throws/raises (or the awaitable rejects), the helper SHALL set status `error`
with the exception message — unless the caller explicitly set status `ok`, which is final —
attach an `exception` span event carrying `exception.type` and `exception.message`, end the
span, and rethrow the original exception unmodified. On error-value platforms (Go, Rust) the
helper SHALL instead treat a non-nil/`Err` callback return as the failure signal and return
it unmodified. `exception.type` derives from the platform's error type name, and
`exception.message` from its message/description accessor. `recordException(error)` SHALL
apply the same status-and-event treatment on a manually managed span without ending it. The
`ok`-is-final rule guards only the helper's *automatic* recording: explicit `setStatus` calls
and `recordException` (itself an explicit call) follow last-write-wins.

The `exception` event SHOULD also carry `exception.stacktrace` where the platform exposes a
stack on the thrown value, read behind the SDK's own guard so a value without one — or with a
throwing accessor — costs the attribute rather than the span. Because a stack is unbounded and
per-exception, it SHALL be subject to `maxAttributeValueLength` like any other attribute value,
and it SHALL be attached before `beforeSpanSend` runs so a hook can scrub or remove it. SDKs
that cannot obtain a stack safely MAY omit the attribute.

#### Scenario: callback exception is recorded and rethrown
- **WHEN** `withSpan("job", fn)` runs an `fn` that throws `TypeError("boom")`
- **THEN** the span is exported with status `error` and an `exception` event with
  `exception.type` "TypeError" and `exception.message` "boom"
- **AND** the caller still receives the original `TypeError`

#### Scenario: async callback ends at settle
- **WHEN** `withSpan("job", fn)` runs an `fn` returning a Promise that resolves 80ms later
- **THEN** the span ends at settle and its duration covers the 80ms

#### Scenario: helper ends the span on success
- **WHEN** `withSpan("job", fn)` completes normally
- **THEN** the span is ended with its status untouched (unset)
- **AND** the callback's return value is returned to the caller

#### Scenario: recordException does not end the span
- **GIVEN** a manually managed span
- **WHEN** `recordException(err)` is called and work continues
- **THEN** the span carries status `error` and an `exception` event, remains live, and ends
  only at the explicit `end()`

#### Scenario: context manager form
- **GIVEN** a Python SDK
- **WHEN** the app uses `with posthog.start_span("job"):`
- **THEN** the span starts on entry, is active inside the block, and ends on exit

#### Scenario: stack is captured and bounded
- **GIVEN** `maxAttributeValueLength` is 8192
- **WHEN** `recordException(err)` is called with an error whose stack is 40000 characters
- **THEN** the `exception` event carries `exception.stacktrace` truncated to 8192 characters

#### Scenario: a scrubbing hook can remove the stack
- **GIVEN** a `beforeSpanSend` hook that deletes `exception.stacktrace` from every event
- **WHEN** a span records an exception and is exported
- **THEN** the exported event carries `exception.type` and `exception.message` and no
  `exception.stacktrace`

### Requirement: Trace and span identifiers

The SDK SHALL generate identifiers per the W3C Trace Context spec: a random 16-byte trace id
and a random 8-byte span id from a cryptographically secure or equivalently
collision-resistant source, neither all-zero. A root span (no active or explicit parent) gets
a fresh trace id; a child span inherits its parent's trace id and records the parent's span
id as `parentSpanId`. On the JSON wire, ids SHALL be lowercase hex — 32 characters for trace
ids, 16 for span ids; in protobuf they are the raw bytes. The SDK SHALL never emit an id of
any other length: the ingestion service zeroes wrong-length ids rather than rejecting them,
silently orphaning the span.

#### Scenario: root span gets fresh well-formed ids
- **WHEN** a span starts with no active parent
- **THEN** its JSON record carries a 32-char lowercase-hex `traceId`, a 16-char lowercase-hex
  `spanId`, neither all zeros, and no `parentSpanId`

#### Scenario: child inherits trace id
- **GIVEN** an active span A with trace id T
- **WHEN** a child span B starts under it
- **THEN** B's record carries trace id T and `parentSpanId` equal to A's span id

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
variation: Python SHALL use `contextvars`; Node SHOULD use `AsyncLocalStorage`; the browser
MAY be limited to synchronous scoping (no async continuation tracking); mobile ports SHOULD
use their structured-concurrency context primitive (coroutine context on Android, task-local
values on Swift) with a thread-local fallback. Platforms without an ambient context primitive
(e.g. Go) MAY surface the active span as an explicit context value instead — the scoped
helper passes a derived context to its callback, and `startSpan`/`getActiveSpan` accept a
context argument — provided default-parenting, helper-only activation, and null-when-absent
semantics are preserved.

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
`traceparent`. An invalid `traceparent` SHALL be ignored (fresh root context); an invalid
`tracestate` SHALL be discarded without invalidating the `traceparent`. Automatic header
injection/extraction is out of scope for this capability and arrives with per-platform
instrumentation. This capability is distinct from the `tracing-headers` capability
(`X-POSTHOG-*` identity headers), which operates independently.

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

`startTimeUnixNano` is captured at `startSpan` time unless the caller supplied `startTime`,
which wins. For spans started "now", the SDK SHOULD derive the end time — and each event's
`timeUnixNano` — from a monotonic clock elapsed since start, so durations survive wall-clock
adjustments and event timestamps land within the span window; where the platform
distinguishes them, the clock SHALL be one that advances during device sleep (Android
`elapsedRealtime`, Swift `ContinuousClock`). Backdated spans (explicit `startTime`) use wall
clock. `addEvent` MAY accept an explicit timestamp. Span names SHALL be low-cardinality
operation names (`GET /users/:id`, `db.query cart`); variable values belong in attributes,
never interpolated into the name — the product aggregates operations by (service, name).
Span links are reserved at the wire level and are not part of the v1 public API.

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

### Requirement: Client-side validity

Because one malformed span rejects the entire request server-side, the SDK SHALL enqueue only
well-formed records, sanitizing at end time: ids well-formed per the identifier requirement;
`name` non-empty (an empty or non-string name at `startSpan` or `updateName` SHALL be
replaced with `unknown` plus a debug warning); timestamps within `[0, i64::MAX]` nanoseconds
— OTLP declares the fields `fixed64` but the service parses signed 64-bit, so a negative
(pre-epoch) value is as invalid as an overflow — a `startTime`, `endTime`, or event timestamp
outside that range SHALL be replaced with the current time (for `endTime`, the derived end);
end-before-start SHALL be corrected to end = start. The SDK SHOULD warn when a
backdated `startTime` is more than 24 hours old, because the server clamps such timestamps to
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

### Requirement: Span limits

The SDK SHALL cap **user-supplied** per-span content at documented defaults matching
OpenTelemetry's: at most 128 attributes and 128 events per span, configurable. SDK-managed
auto-context keys are exempt from the attribute cap and SHALL never be evicted by it — they
are the product's join keys. On overflow the earliest-set entries win: excess additions SHALL
be dropped silently with the counts reported via `droppedAttributesCount` and
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

### Requirement: Attribute value encoding

Span, event, and resource attribute values SHALL use the same OTLP `AnyValue` encoding as the
logs capability: string → `stringValue`; boolean → `boolValue`; integer → `intValue` as a
stringified int64; float → `doubleValue`; non-finite float → `stringValue`
("NaN"/"Infinity"/"-Infinity"); array → `arrayValue`; map → `kvlistValue`; `null`/`undefined`
SHALL drop the key. An integer outside `[-2^63, 2^63-1]` (e.g. a Python or JS bigint) SHALL
be encoded as `stringValue` (its decimal string) with a debug warning — mirroring the
non-finite-float rule — never as `intValue`, which would 400 the entire batch. Because the ingestion service flattens attribute values to strings for
storage, SDKs SHOULD prefer primitive values and SHOULD document that nested structures
survive only as serialized strings.

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

### Requirement: Auto-captured context attributes

At span start the SDK SHALL enrich the span's attributes with available PostHog context using
the same wire keys as logs: `posthogDistinctId` and `sessionId`, plus the platform navigation
keys (`url.full` on web; `screen.name` and `app.state` on mobile ports). On client platforms
(browser, mobile) the values come from the SDK's process-global identity and session manager.
On server platforms there is no process-global identity: the values SHALL come from the
active request context (the request-context integration that reads `X-POSTHOG-DISTINCT-ID` /
`X-POSTHOG-SESSION-ID`, per the `tracing-headers` capability), and with no request context
the keys are omitted. The snapshot SHALL be frozen at span start, keys SHALL be omitted when
the value is absent or empty, and user-supplied attributes SHALL win on collision. The
`feature_flags` key that logs auto-attaches is deliberately excluded (span volume is
multiplicative). These keys are what make PostHog traces joinable to persons, sessions, and
logs; ports SHALL NOT rename them.

#### Scenario: distinct id snapshot frozen at start
- **GIVEN** a span started while the distinct id is "a"
- **WHEN** the user is identified as "b" before the span ends
- **THEN** the exported span carries `posthogDistinctId` "a"

#### Scenario: absent session omits the key
- **WHEN** a span starts with no active session (e.g. a Python server process)
- **THEN** the record has no `sessionId` attribute

#### Scenario: user attribute wins
- **WHEN** a span sets `attributes: { posthogDistinctId: "override" }`
- **THEN** the exported value is "override"

### Requirement: Resource and scope

The OTLP envelope SHALL carry resource attributes describing the producing service —
`service.name` (always emitted: the configured value, else `unknown_service`, the bare form
of OpenTelemetry's `unknown_service:<process>` convention, chosen for cross-platform
consistency), optional `service.version` and `deployment.environment`, `telemetry.sdk.name`,
`telemetry.sdk.version`, `os.name`, `os.version` — plus user-supplied `resourceAttributes`,
with SDK-managed identity keys (`service.*`, `telemetry.sdk.*`) winning on collision. The
scope SHALL be `{ name, version }` identifying the SDK; the server flattens it to
`"{name}@{version}"`. The SDK SHALL always send `service.name`: the server reads
`service_name` only from that attribute and stores an empty string when it is missing,
leaving spans unattributable in the product.

#### Scenario: service name always present
- **WHEN** the app configures no `serviceName`
- **THEN** the resource carries `service.name` `unknown_service` rather than omitting the key

#### Scenario: identity keys protected
- **WHEN** `resourceAttributes` includes `telemetry.sdk.name: "custom"`
- **THEN** the emitted `telemetry.sdk.name` is the SDK's own identity

### Requirement: Payload envelope

A single export batch SHALL produce exactly one `resourceSpans` entry containing exactly one
`scopeSpans` entry containing N `spans`.

#### Scenario: one batch one envelope
- **WHEN** a batch of 20 spans is assembled
- **THEN** the payload has one `resourceSpans[0].scopeSpans[0].spans` array of length 20

### Requirement: HTTP transport

The SDK SHALL POST batches to `{host}/i/v1/traces`, where `host` is the configured ingestion
host with any trailing slash stripped, constructing the full path itself (never delegating to
a base-endpoint convention that appends `/v1/traces`). Auth SHALL use
`Authorization: Bearer {projectApiKey}` as the primary method, with the URL-encoded
`?token={projectApiKey}` query parameter as a fallback for platforms or send modes that
cannot set headers — or, on the browser, that deliberately avoid them: pairing `?token=` auth
with the `?compression=gzip-js` signal keeps requests free of the CORS preflight that
`Authorization`, `Content-Encoding`, and a non-safelisted `Content-Type` would force. The
body SHALL be OTLP: protobuf (`Content-Type: application/x-protobuf`) is canonical where the
encoder adds no meaningful dependency or binary-size cost (server platforms with mature
codegen); mobile ports and the browser SHOULD send JSON (`Content-Type: application/json`) —
the same protobuf-dependency-cost tradeoff the logs SDKs make. The service never reads
`Content-Type` (it sniffs the body, protobuf-first), so the browser SHOULD instead send the
JSON body as `Content-Type: text/plain` — a CORS-safelisted type, unlike `application/json`
— completing the preflight-free send. A successful response is HTTP 200 with body `{}`; the
SDK SHALL treat any 2xx as success. This endpoint is exclusively for distributed-tracing
spans — LLM analytics spans go to a different product endpoint.

#### Scenario: endpoint and bearer auth
- **WHEN** the SDK flushes with host `https://us.i.posthog.com` and key `phc_abc`
- **THEN** it POSTs to `https://us.i.posthog.com/i/v1/traces` with header
  `Authorization: Bearer phc_abc`

#### Scenario: token query param fallback
- **GIVEN** a platform that cannot set request headers
- **WHEN** the SDK flushes with host `https://us.i.posthog.com` and key `phc_abc`
- **THEN** it POSTs to `https://us.i.posthog.com/i/v1/traces?token=phc_abc` with no
  `Authorization` header

#### Scenario: browser send avoids CORS preflight
- **GIVEN** a browser SDK flushing a gzipped JSON batch
- **WHEN** the POST is built
- **THEN** it uses `?token={projectApiKey}&compression=gzip-js` with
  `Content-Type: text/plain` and no `Authorization` or `Content-Encoding` header
- **AND** the request qualifies as a CORS simple request (no preflight)

### Requirement: Compression

The SDK SHALL gzip the request body by default — protobuf or JSON alike — signaling with
`Content-Encoding: gzip` (preferred) or the `?compression=gzip` / `?compression=gzip-js`
query parameter the server translates into the header. The server additionally sniffs gzip
magic bytes, but the SDK SHALL still signal explicitly. Where gzip is unavailable — including
send modes that cannot set headers, such as the unload beacon — the SDK SHALL send the raw
body with no `Content-Encoding`. There SHALL be no size threshold for compression.

#### Scenario: gzipped batch
- **WHEN** a platform with gzip support flushes
- **THEN** the body is gzipped and sent with `Content-Encoding: gzip`

#### Scenario: gzip unavailable
- **GIVEN** a platform with no gzip primitive
- **WHEN** the SDK flushes
- **THEN** the raw body is sent with no `Content-Encoding` header

### Requirement: Span queue

Ended spans SHALL be appended to an **in-memory** export queue bounded by `maxQueueSize`;
live (unended) spans never occupy the queue. The in-memory choice is deliberate on all
platforms, including mobile — diverging from the logs persistent queue — because a rehydrated
partial trace has little value once its parent spans are gone; spans queued at process death
are accepted loss. A mobile port MAY propose a persistent queue as a documented deviation in
its port change, but SHALL NOT persist by default. On overflow the SDK SHALL drop the
**incoming** span — never evict already-queued spans, whose parents may already be exported
(deliberately diverging from the logs drop-oldest rule, which suits self-contained records
but breaks assembled traces).

#### Scenario: overflow drops the new span
- **GIVEN** the queue is at `maxQueueSize`
- **WHEN** another span ends
- **THEN** that incoming span is dropped and queued spans are untouched

### Requirement: Live span bounds

The SDK SHALL bound live spans: at most `maxLiveSpans` concurrently, and no live span older
than `maxSpanAgeMs`. The default SHALL comfortably exceed the platform's realistic worst-case
trace duration — on the order of an hour, not minutes (production PostHog traces routinely
exceed 10 minutes); mobile ports MAY choose a larger default since backgrounded time counts.
Age SHALL be the monotonic elapsed time since handle creation, independent of any
caller-supplied `startTime` — a backdated span is not instantly evicted, a future-dated
leaked span cannot evade the bound, and wall-clock jumps do not affect it. At the count bound, `startSpan`
returns a no-op handle. A live span exceeding the age bound SHALL be evicted from live
accounting and its handle becomes a no-op (never exported) — eviction prevents a span leak
from permanently disabling tracing for the rest of the process. Eviction MAY be evaluated
lazily — at the next span start, span end, or flush tick — no dedicated timer is required. A span legitimately spanning
a long mobile background interval will be evicted by this rule; that is expected behavior,
not a defect. All span drops — live-bound refusals, age evictions, queue overflow, and
end-time gate drops — SHALL increment a single per-instance dropped-spans counter, with a
warning at most once per flush interval naming the count and reason mix.

#### Scenario: leaked spans are bounded
- **GIVEN** the live-span bound is reached because spans are started but never ended
- **WHEN** the app calls `startSpan` again
- **THEN** it receives a no-op handle, the dropped count increments, and SDK memory does not
  grow further

#### Scenario: age eviction re-enables tracing
- **GIVEN** `maxLiveSpans` handles leaked (started, never ended) longer than `maxSpanAgeMs`
  ago
- **WHEN** the age bound passes and the app calls `startSpan`
- **THEN** the leaked spans are evicted (never exported) and the new span is a real span

### Requirement: Flush triggers

The SDK SHALL flush on each applicable trigger: (1) a repeating timer at `flushIntervalMs`;
(2) queue depth reaching `maxExportBatchSize`; (3) a manual `flush()` — the SDK's global
`flush()` SHALL drain the traces queue alongside events, logs, and replay; (4) the app
entering background / the platform lifecycle suspend (mobile ports), flushing before the OS
suspends the process; (5) page unload via a beacon-style send (web) — beacons cannot set
headers and carry a small body budget (~64 KB), so the unload path SHALL use the `?token=`
auth fallback with a raw (uncompressed) reduced batch, and spans that do not fit remain
queued and may be lost with the page; (6) network connectivity being restored, where the
platform exposes it. There is deliberately no client-side rate cap (unlike logs): span
volume is bounded by instrumentation, and `maxQueueSize`, `maxLiveSpans`, and
`beforeSpanSend` are the pressure valves.

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

### Requirement: Shutdown flush

On SDK shutdown/close the SDK SHALL attempt a final flush of queued spans bounded by a
timeout. Spans still live (unended) at shutdown MAY be ended at shutdown time or discarded,
but the choice SHALL be documented; queued spans SHALL NOT be silently discarded. On mobile,
process termination delivers no shutdown callback — the background-flush trigger is the
effective substitute.

#### Scenario: bounded final flush
- **WHEN** the SDK shuts down with queued spans
- **THEN** it attempts to send them within a bounded time budget before stopping

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

### Requirement: Gating and beforeSpanSend

Tracing public APIs SHALL never surface an SDK-originated failure to the caller, and tracing
background work SHALL never crash application code — the same two-sided rule the capture and
retry-queue specs establish. (The scoped helper rethrowing the application's own callback
exception is propagation of app control flow, not an SDK throw.)
A span SHALL be dropped at end time (never throwing) when any gate fails, evaluated in order:
(1) SDK not enabled/initialized, (2) user opted out, (3) `beforeSpanSend` returned `null`;
the span-limit caps and client-side validity sanitization then apply to whatever the hook
returned, before enqueue. There SHALL be no remote kill-switch gate on span capture in v1,
and opting out mid-trace SHALL stop subsequent spans from exporting without throwing into
code holding live span handles.

`beforeSpanSend` SHALL receive the completed span as a plain pre-encoding representation
(name, kind and status as strings, attributes as a plain map — not the OTLP wire encoding),
including **read-only** `traceId`, `spanId`, and `parentSpanId` — exposed so hooks can make
trace-consistent decisions (e.g. sampling on a `traceId` hash), never mutated: a change to an
identity field SHALL be ignored with a debug warning, since rewriting ids after children
exist corrupts parentage. The hook runs after auto-context attributes are attached and may
mutate the rest or drop the span; a single function or an array run left-to-right. It is the designated scrubbing point for sensitive attribute
values, and SDK documentation SHALL present it as such — for that reason a hook that throws
SHALL drop the span (fail-closed): a broken scrubber must not leak the unscrubbed record.
This is the same rule the logs `beforeSend` hook follows, for the same reason.

#### Scenario: beforeSpanSend drops a span
- **WHEN** `beforeSpanSend` returns `null` for a span
- **THEN** the span is not enqueued and no error surfaces

#### Scenario: throwing hook fails closed
- **GIVEN** a `beforeSpanSend` that throws
- **WHEN** a span ends
- **THEN** the span is dropped, the error is swallowed with a warning, and nothing unscrubbed
  is exported

#### Scenario: hook sees friendly attributes
- **WHEN** `beforeSpanSend` inspects a span with attribute `userId: 42`
- **THEN** it reads a plain map entry `userId: 42`, not an OTLP `{ "intValue": "42" }`
  structure

#### Scenario: identity fields are readable but immutable
- **WHEN** `beforeSpanSend` reads `traceId` and assigns a new value to it
- **THEN** the read succeeds, the assignment is ignored with a debug warning, and the
  exported record keeps the original ids

#### Scenario: opt-out mid-trace is safe
- **GIVEN** a live span started before opt-out
- **WHEN** the user opts out and the span later ends
- **THEN** nothing is exported and no error is thrown

### Requirement: Configuration knobs

The SDK SHALL expose a `traces` configuration object with: `serviceName`, `serviceVersion`,
`environment`, `resourceAttributes`, `flushIntervalMs`, `maxQueueSize`,
`maxExportBatchSize`, `maxLiveSpans`, `maxSpanAgeMs`, `maxAttributesPerSpan`,
`maxEventsPerSpan`, `maxAttributeValueLength`, and `beforeSpanSend` — spelled per platform
convention. `serviceName`, `serviceVersion`, `environment`, and `resourceAttributes` SHALL
carry the same meaning and shape as the matching logs config keys. There is deliberately no
separate flush-threshold knob: `maxExportBatchSize` doubles as the depth trigger, matching the
OpenTelemetry batch-processor model. Defaults MAY differ by platform but SHALL be deliberate
and documented. Tracing SHALL be off until the `traces` config is provided while the product is
pre-GA; enabling it SHALL require no more than providing that config.

A value supplied for a numeric knob that is not a positive integer SHALL fall back to the
documented default rather than reaching the export loop, and a `beforeSpanSend` entry that is
not callable SHALL be ignored rather than invoked — an untyped caller passing the wrong shape
must not silently disable tracing.

#### Scenario: off until configured
- **GIVEN** an SDK initialized with no `traces` config
- **WHEN** the app calls `startSpan("x")` and `end()`
- **THEN** a no-op handle is returned and nothing is exported

#### Scenario: shared vocabulary
- **WHEN** a developer who has configured PostHog logs configures traces
- **THEN** `serviceName`, `environment`, and `resourceAttributes` carry the same meaning and
  shape as in the `logs` config

#### Scenario: deliberate defaults
- **WHEN** a new SDK implements traces
- **THEN** it documents its chosen flush interval, queue size, export batch size, and
  attribute value length rather than copying another platform blindly

#### Scenario: an unusable knob value falls back
- **WHEN** an untyped caller sets `maxAttributesPerSpan` to `0` and `beforeSpanSend` to a
  non-callable value
- **THEN** the SDK uses its documented attribute cap and exports spans unhooked, rather than
  stalling or dropping every span

### Requirement: Server-side contract

The SDK SHALL design to the ingestion service's observed contract. The request body is
capped at 2 MB, raw or gzip-decompressed; exceeding it returns 413. A request with no token
at all returns 401, as does a manually-blocked token. A token whose *shape* rules it out as a
project API key (wrong prefix such as `phx_`, over 64 characters, non-ASCII, empty) also returns
401: posthog/posthog#76501, split out of the abandoned #75090, landed shared shape validation in
the capture-logs authorizer on 2026-08-04, and the traces, logs and metrics endpoints all run it.
A **well-formed but unknown token is still accepted with 200**, and that is the gap that matters:
capture does not resolve tokens against projects (that would require Postgres at the
ingest edge), so a mistyped-but-plausible `phc_` key produces successful-looking responses
while every span is dropped downstream, and the SDK cannot detect this from responses. SDK
documentation SHALL NOT present a 2xx export as confirmation that tracing is correctly
configured. The body is decoded as OTLP protobuf
first, then JSON (a single `ExportTraceServiceRequest` object or JSONL lines merged); a body
that decodes as neither returns 400. A span whose fields fail decoding or row conversion —
e.g. a timestamp that does not fit signed 64-bit nanoseconds — **400s the entire request**,
which is why the client-side validity requirement exists; note the distinction between an
*unrepresentable* timestamp (rejected) and a representable-but-stale one (clamped, below).
Success is 200 with body `{}`. The service emits only 200/400/401/413/500 and never
`429`/`Retry-After`/`quota_limited`. posthog/posthog#75090 would have added per-signal quota
enforcement at capture, giving an over-quota project **429 with `Retry-After`** before anything
reached Kafka, with logs, metrics and traces each on their own bucket; it was closed unmerged on
2026-08-17. Only its token-shape half was salvaged, as #76501 above; the quota half has no
replacement. So any `429` with a `Retry-After` that an SDK sees comes
from shared infrastructure in front of capture — a proxy, CDN or load balancer — which is also why
the retry requirement bounds how long the SDK will honor one. The SDK SHALL NOT *require* a quota
signal, but SHALL honor `429` + `Retry-After` when present — the retry requirement already does.

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
- **WHEN** a request body exceeds 2 MB
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

