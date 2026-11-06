## Context

The goal is a reliable link from an error to its trace, and from there to logs and the session. PostHog already joins these in the product: the tracing UI matches exceptions to spans by `$trace_id` and `$session_id`, and the error tracking UI reads `$trace_id` and `$span_id` from exception events. The missing part is the producer side: not every SDK writes the IDs.

Evidence from shipped SDKs:

- `posthog-python` reads the ambient OpenTelemetry span at exception capture. It writes `$trace_id` as 32 lowercase hex characters and `$span_id` as 16, zero-padded. It checks only that the span context is valid, not that the span is sampled. It writes nothing when OpenTelemetry is not installed, when no span is active, or when the span context is invalid. It imports OpenTelemetry lazily and treats a failed import or a failed read as "no trace context".
- `posthog-node` has a span API (`traces` capability) and a request context, but exception events carry no trace or span ID.
- `posthog-python` reads only the ambient OpenTelemetry span for this. Its own span API keeps a separate active-span variable that the exception path does not read, so an exception inside such a span is not stamped. This was read from the client code, not proven by a test.

## Decisions

### Spec the ambient OpenTelemetry span only

The requirement is limited to the ambient OpenTelemetry span. This is the only behavior that ships today, and the repo rule is that every requirement traces to shipped behavior.

Alternative: also require the SDK's own active span (`traces` capability). It is the better end state, because a user of the PostHog span API gets linked errors without installing OpenTelemetry. No SDK does it yet. It should be added as a separate change after one SDK ships it.

### Server SDKs only

Browser and mobile SDKs have no ambient OpenTelemetry API, so they do not derive the properties. The requirement says so, because the capability spec is marked `both` and a delta cannot edit its applicability prose.

### No hard dependency on OpenTelemetry

An SDK must not require OpenTelemetry to be installed. It looks the API up only when the application already provides it. This follows `posthog-python`, and it keeps OpenTelemetry out of the dependency tree of applications that do not use it.

### Allowed variation for non-OpenTelemetry names

.NET OpenTelemetry uses `System.Diagnostics.Activity`. The requirement lets such a platform read its own ambient API instead of the OpenTelemetry package.

### One text form for IDs

Other PostHog stores keep trace IDs in other encodings (for example base64 in the spans table). Event properties are plain strings, so the contract fixes lowercase hex, exact length, leading zeros kept, no separators or version prefix. This matches the W3C Trace Context text form and what `posthog-python` writes. A naive integer-to-hex conversion drops leading zeros, so the spec has a scenario for it.

### Omit, never invent

When there is no valid span, the SDK does not derive the properties. Caller-supplied properties can still be present. An all-zero ID is the OpenTelemetry marker for "no span", so it is treated as invalid. This keeps a missing SDK-derived link visible as a missing link.

### Stamp spans that are not sampled

The IDs are set even when the span is not sampled for export. This matches `posthog-python`, and the IDs still identify the failing work. The cost is that the ID can point at a trace PostHog never received.

### Precedence is left open

An earlier draft said a caller-supplied `$trace_id` or `$span_id` must win. It was removed. The file already has a precedence model for SDK-owned metadata, and the property-bag override that `posthog-python` allows for SDK-owned keys is being deprecated. This change does not define precedence for the new keys; it stays implementation-specific, as the merge order does in `capture-exception`.

## Risks and trade-offs

- A span that was sampled out or not exported means the ID points at a trace PostHog never received. The product should show "trace not kept" instead of a dead link. This is a product concern, not an SDK one.
- Reading the ambient span adds a small cost to every exception capture. The read is a local lookup.
- Reading the ambient span can fail (for example, a broken OpenTelemetry install). The spec says capture continues without SDK-derived trace properties. That case is in the spec, but not in the acceptance feature, because an adapter cannot cause the failure through public behavior.

## Open questions

- Should `capture` events carry the same IDs by default? `posthog-python` has an opt-in option, off by default. A shared default needs more evidence about volume and privacy.
- Should the SDK's own span API activate the ambient OpenTelemetry context, or should exceptions read both? See the second alternative above.
- Should the contract define precedence for caller-supplied values once the property-bag deprecation is settled?
- Which attribute name should future frontends use if the browser starts trace contexts? Tracked in PostHog/sdk-specs#122.
