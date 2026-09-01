## Context

The traces capability was written before any SDK implemented it, from a design that
deliberately kept v1 small. `posthog-node` is the first port. Reviewing it end to end
(PostHog/posthog-js#4579 and the PRs stacked on it) surfaced three assumptions in the spec
text that the implementation could not honour without producing a worse result. This change
records the corrections rather than letting the reference implementation diverge quietly.

## Goals / Non-Goals

- **Goals:** keep a partially-instrumented fleet's traces connected; keep what the SDK
  propagates truthful to a downstream sampler; make a single oversized attribute cost its own
  value rather than the whole span.
- **Non-Goals:** head sampling (the SDK still records every captured span), automatic header
  injection/extraction, span links, changing the ingestion contract.

## Decisions

### Pass-through inert handles

**Decision.** Split "inert" into two kinds. A handle with no inbound context stays a strict
no-op. A handle created from a valid inbound `traceparent` echoes it and is activated by
scoped helpers.

The v1 rule — never activated, never a well-formed header — exists to stop the SDK
propagating an id that was never recorded. A pass-through handle does not do that. The id it
forwards is the upstream caller's, and upstream recorded it; the SDK invents nothing. What the
v1 rule actually cost was every service in the middle of a chain that had not enabled `traces`
yet: it forwarded no header, so each downstream hop started a fresh trace and the chain broke
at the least-instrumented service.

OpenTelemetry treats this as the one exception to no-op behavior. With no SDK installed "the
API MUST return a non-recording `Span` with the `SpanContext` in the parent `Context`", and
that context "will be propagated through to any child span and ultimately also `Inject`".

The echo is verbatim, including the inbound **version** byte, because a pass-through handle
re-emits a header it did not construct. That differs from a recorded span, which mints a new
span id and therefore emits under the version it knows how to write (`00`).

**Alternatives considered.** Leave it and document the gap — rejected: the propagation example
in the SDK's own docstring silently does nothing on that path. Return a recording span instead
— rejected: it would record spans for a service that has not opted into tracing.

### Propagating the inbound sampled bit

**Decision.** Propagate the inbound bit; keep recording the span regardless.

Always sending `01` is legal (W3C lists "update sampled" as a permitted mutation when
parent-id changes) and truthful about *this* SDK, which records everything. The cost is
downstream: a head-sampled fleet's `00` becomes `01` at the PostHog hop, and the next OTel
service's default `ParentBased` sampler records a trace its own head sampler already rejected,
producing paid-for fragments with no root.

Recording and propagating are separable, and OpenTelemetry already names this combination
`RECORD_ONLY`. Taking it also makes the tracing-on and tracing-off paths agree: a
pass-through handle echoes the inbound byte, so before this change the same service returned
`-01` with tracing on and `-00` with tracing off for the same request.

Undefined bits are a separate matter. A continued span re-emits under version `00`, and W3C
requires a vendor to zero flags that version does not define rather than forward bits it
cannot interpret. Masking at parse time — rather than at each emit site — keeps the header and
the wire `flags` from disagreeing about the same byte.

**Confirmed before proposing:** ingestion stores `flags` verbatim and reads nothing from it, so
a `flags` byte with the sampled bit clear changes no server behavior today.

### Bounding attribute value length

**Decision.** Add `maxAttributeValueLength`, applied to every string reachable in a value.

The count caps bound how many entries a span carries, not how big one is. A single
multi-megabyte value pushes the span past the ingestion body limit; the too-large path then
halves the batch down to that span alone, finds it still too large, and drops it whole. The
user loses the span rather than the excess — the opposite of what the caps are for.

The bound has to reach inside arrays and maps. `setAttribute("payload", { body: res.body })` is
the ordinary way an oversized value arrives, and a bound that only sees top-level strings
misses it entirely. Traversal is depth-limited so a self-referencing value terminates, and a
value whose accessors throw is left alone rather than taken as a reason to drop the span.

OpenTelemetry leaves `attributeValueLengthLimit` unlimited by default and drops the whole batch
on failure. PostHog's export drops only the offending span, which is better, but a finite
default is better still.

### `exception.stacktrace`

**Decision.** Add it as a SHOULD, ordered after the scrub hook and inside the value bound.

The add-traces design deferred it explicitly and invited this follow-up: "`exception.type` /
`exception.message` are the v1 contract, and ports may propose the stacktrace attribute … as a
follow-up." The reason to defer was that no scrub hook and no size bound existed yet, so a
stack could be neither removed nor trimmed. Both now exist, which is what unblocks it.

Ordering matters and is therefore normative: the stack is attached before `beforeSpanSend`, so
a hook can drop it, and the value bound is applied after, so a hook cannot reintroduce an
unbounded one. Adding stacks silently in a later release would change what leaves customer
servers, so it ships as a documented, disclosed change.

## Risks / Trade-offs

- **A pass-through service reports no spans but forwards context.** Traces will show a gap
  where that service sits. This is strictly better than the chain breaking, and it disappears
  when that service enables `traces`.
- **Propagating `00` means downstream parent-based samplers will not record.** That is the
  point, but it does mean a PostHog-traced service no longer "rescues" a sampled-out trace for
  other vendors. Documented rather than made configurable; a sampling knob is future work.
- **A finite value bound truncates data that previously arrived intact** — but only on spans
  that would previously have been dropped whole.
- **`exception.stacktrace` increases span size** and can carry sensitive paths or values. It is
  bounded, scrubbable, and omittable by SDKs that cannot read a stack safely.

## Open Questions

- Should `maxAttributeValueLength` share one default across SDKs, or stay per-platform like the
  other knobs? `posthog-node` chose 8192. A single documented number would make cross-SDK spans
  comparable; per-platform matches how every other knob in this capability is specified.
