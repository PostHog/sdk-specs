## Why

Exception events are the starting point for most debugging. To go from an exception to the backend trace that produced it, the event must carry the trace and span IDs of the work that failed.

Today `posthog-python` adds `$trace_id` and `$span_id` to every `$exception` event when an OpenTelemetry span is active. `posthog-node` does not, even though it can run inside an OpenTelemetry span. No spec says which behavior is correct, so the two SDKs differ and PostHog cannot rely on the join.

## What Changes

- Add a requirement to `exception-event-metadata`: when an OpenTelemetry span is active at capture time, the `$exception` event carries `$trace_id` and `$span_id`.
- Define the ID format (lowercase hexadecimal, 32 and 16 characters) so every SDK writes the same text form.
- Define when the properties are omitted: no active span, an invalid span, or no OpenTelemetry API on the platform.
- Define that a caller-supplied value for either property is kept.
- Define that a failure to read the trace context never drops the event.

Not in this change, because no shipped SDK implements them yet (see `design.md`):

- Trace IDs from an SDK's own span API (`traces` capability) on exception events.
- Trace IDs on other events (`capture`). `posthog-python` has an opt-in option for this; it is not a common contract yet.
- Browser-created trace IDs, W3C baggage, or `tracestate` propagation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: add the active trace context requirement for server SDKs that run inside OpenTelemetry spans.

## Impact

`posthog-python` already conforms. `posthog-node` does not conform until it reads the ambient OpenTelemetry span at capture time. SDKs for platforms without an OpenTelemetry API are not affected, because they omit the properties.

The PostHog tracing and error tracking UI already read `$trace_id` and `$span_id` from exception events. No backend change is needed.

Cross-SDK discussion: PostHog/sdk-specs#122.
