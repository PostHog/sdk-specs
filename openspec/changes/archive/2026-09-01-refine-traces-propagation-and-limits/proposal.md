## Why

The traces capability was specified before any SDK implemented it. Implementation review of
the first port (`posthog-node`, PostHog/posthog-js#4579 and its stack) surfaced three places
where the v1 text assumes something the reference implementation found to be wrong or
incomplete. Each is a cross-SDK contract, so each needs deciding here rather than per port.

1. **Trace context is severed by a service that has tracing off.** The spec says a no-op
   handle SHALL never be activated and SHALL never produce a well-formed `traceparent`. That
   rule is right for a handle with nothing behind it, but it also silences a service in the
   middle of a traced chain that simply has not enabled `traces` yet: it forwards no header,
   and every downstream service starts a fresh trace. The OpenTelemetry API spec makes this
   the one exception to no-op behavior — with no SDK installed "the API MUST return a
   non-recording `Span` with the `SpanContext` in the parent `Context`" — precisely so a
   pass-through service keeps the chain intact. Echoing an inbound header invents no ids: the
   span id propagated is the upstream caller's, and upstream recorded it.

2. **The inbound sampled flag is discarded.** The spec pins `traceparent` at `-01` and the
   wire `flags` low byte at `1`. Legal under W3C, and truthful while the SDK records every
   captured span — but it breaks interop with head-sampled fleets. Service A samples a trace
   out (`00`), a PostHog-traced service B continues it and propagates `01`, and a downstream
   OTel service C with the default `ParentBased` sampler then records a trace its own head
   sampler had already rejected. Propagating the flag and recording the span are separate
   decisions; OpenTelemetry's `RECORD_ONLY` shape is exactly this case.

3. **Nothing bounds the size of a single attribute value.** The count caps (128 attributes,
   128 events) do not stop one multi-megabyte value. That value takes the whole span past the
   ingestion body limit, the 413 path shrinks the batch to that span alone, and the span is
   dropped whole rather than trimmed. `exception.stacktrace` — deliberately deferred from v1
   by the add-traces design, which invited exactly this follow-up — is the case that makes the
   bound necessary rather than optional, since a stack is per-exception and unbounded.

## What Changes

- Distinguish a **pass-through inert handle** from a **no-op handle**. When a span cannot be
  recorded but the caller supplied a usable inbound `traceparent`, the returned handle echoes
  that context and is activated by scoped helpers, so `getActiveSpan()` inside the callback
  can propagate it. The no-op handle keeps its current contract unchanged.
- Propagate the inbound sampled bit in both `span.traceparent()` and the wire `flags` field,
  so the header and the record agree; keep setting the bit for a trace the SDK starts. Require
  flag bits that version `00` does not define to be zeroed on emit, per W3C.
- Allow OpenTelemetry's has-is-remote / is-remote flag bits to be set from parent remoteness,
  which the SDK always knows.
- Add `maxAttributeValueLength` to the span limits and to the configuration knobs, bounding
  every string an attribute value contains, including strings nested inside arrays and maps.
- Add `exception.stacktrace` to exception recording as a SHOULD, bounded by that knob and
  visible to `beforeSpanSend` so it can be scrubbed or dropped before export.

The three are independent and may be accepted separately.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `traces`: Define pass-through inert handles, inbound sampled-flag propagation, an attribute
  value-length bound, and optional `exception.stacktrace`.

## Impact

- `posthog-node` implements all three today; this proposal makes the canonical text match
  rather than leaving the reference implementation silently divergent.
- Future traces ports (browser, React Native, Python, iOS, Android) inherit the same handle
  semantics, flag propagation, knob name, and default.
- No wire-format break: `flags` gains values the server already stores without interpreting,
  and `exception.stacktrace` is an additional event attribute.
- Behavior change for a service with tracing off that is handed a `parent`: it now forwards
  the inbound header where it previously forwarded nothing. No span is recorded either way.
