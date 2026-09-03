## MODIFIED Requirements

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
