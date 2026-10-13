## Why

Exception events are the starting point for most debugging. To go from an exception to the backend trace that produced it, the event must carry the trace and span IDs of the work that failed.

Today `posthog-python` adds `$trace_id` and `$span_id` to every `$exception` event when an OpenTelemetry span is active. `posthog-node` does not, even though it can run inside an OpenTelemetry span. No spec says which behavior is correct, so the two SDKs differ and PostHog cannot rely on the join.

## What Changes

- Add a requirement to `exception-event-metadata` (server SDKs): when a valid span from the ambient OpenTelemetry API is active at capture time, the `$exception` event carries `$trace_id` and `$span_id`.
- Define the ID format: lowercase hexadecimal, exactly 32 and 16 characters, leading zeros kept.
- Define that the IDs are set whether or not the span is sampled.
- Add a second requirement for the absent and failure cases: do not derive the IDs when there is no valid span or ambient tracing API; never make OpenTelemetry a required dependency; never drop the event if reading the trace context fails.
- Allow SDKs to read a platform-native tracing API used by OpenTelemetry (for example .NET `Activity`).
- Add acceptance scenarios and one canonical example event.

Not in this change, because no shipped SDK implements them yet (see `design.md`):

- Trace IDs from an SDK's own span API (`traces` capability) on exception events.
- Trace IDs on other events (`capture`). `posthog-python` has an opt-in option for this; it is not a common contract yet.
- Precedence between caller-supplied properties and the ambient span. It stays implementation-specific, as in `capture-exception`.
- Browser-created trace IDs, W3C baggage, or `tracestate` propagation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: add the active trace context requirement and the absent-or-unreadable requirement for server SDKs.

## Impact

`posthog-python` already conforms. `posthog-node` does not conform until it reads the ambient OpenTelemetry span at capture time. SDKs for platforms without an OpenTelemetry API are not affected, because they omit the properties.

The PostHog tracing and error tracking UI already read `$trace_id` and `$span_id` from exception events. No backend change is needed.

Cross-SDK discussion: PostHog/sdk-specs#122.
