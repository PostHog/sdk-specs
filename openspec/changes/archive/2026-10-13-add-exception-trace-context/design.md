## Context

The goal is a reliable link from an error to its trace, and from there to logs and the session. PostHog already joins these in the product: the tracing UI matches exceptions to spans by `$trace_id` and `$session_id`, and the error tracking UI reads `$trace_id` and `$span_id` from exception events. The missing part is the producer side: not every SDK writes the IDs.

Evidence from shipped SDKs:

- `posthog-python` reads the ambient OpenTelemetry span at exception capture. It writes `$trace_id` as 32 lowercase hex characters and `$span_id` as 16. It writes nothing when OpenTelemetry is not installed, when no span is active, or when the span context is invalid. It builds these properties first and then applies caller properties, so a caller value wins.
- `posthog-node` has a span API (`traces` capability) and a request context, but exception events carry no trace or span ID.
- `posthog-python` reads only the ambient OpenTelemetry span for this. Its own span API keeps a separate active-span variable, so an exception inside such a span is not stamped.

## Decisions

### Spec the ambient OpenTelemetry span only

The requirement is limited to the ambient OpenTelemetry span. This is the only behavior that ships today, and the repo rule is that every requirement traces to shipped behavior.

Alternative: also require the SDK's own active span (`traces` capability). It is the better end state, because a user of the PostHog span API gets linked errors without installing OpenTelemetry. No SDK does it yet. It should be added as a separate change after one SDK ships it.

### One text form for IDs

Other PostHog stores keep trace IDs in other encodings (for example base64 in the spans table). Event properties are plain strings, so the contract fixes lowercase hex without separators or version prefix. This matches the W3C Trace Context text form and what `posthog-python` writes.

### Omit, never invent

When there is no valid span, the properties are absent. An all-zero ID is the OpenTelemetry marker for "no span", so it is treated as invalid. This keeps a missing link visible as a missing link.

### Caller values win

A value the caller passes for `$trace_id` or `$span_id` is kept. This matches `posthog-python` and lets applications that manage trace context themselves stay correct.

## Risks and trade-offs

- A span that was sampled out or not exported means the ID points at a trace PostHog never received. The product should show "trace not kept" instead of a dead link. This is a product concern, not an SDK one.
- An SDK that reads the ambient span adds a small cost to every exception capture. The read is a local lookup.
- Reading the ambient span can fail (for example, a broken OpenTelemetry install). The spec says capture continues without the properties.

## Open questions

- Should `capture` events carry the same IDs by default? `posthog-python` has an opt-in option, off by default. A shared default needs more evidence about volume and privacy.
- Should the SDK's own span API activate the ambient OpenTelemetry context, or should exceptions read both? See the second alternative above.
- Which attribute name should future frontends use if the browser starts trace contexts? Tracked in PostHog/sdk-specs#122.
