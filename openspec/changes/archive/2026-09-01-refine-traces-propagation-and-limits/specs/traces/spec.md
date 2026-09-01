## MODIFIED Requirements

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
