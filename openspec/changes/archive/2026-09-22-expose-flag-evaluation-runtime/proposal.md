## Why

A server that bootstraps a client SDK cannot tell which flags are safe to forward to a browser. Each flag's `evaluation_runtime` (`"all"`, `"client"` or `"server"`) is already in the `/local_evaluation` payload, but server SDKs drop it. posthog-android's `posthog-server` now keeps it and exposes it on the `evaluateFlags()` snapshot (PostHog/posthog-android#805). The spec should record the accessor's contract so other server SDKs converge on the same shape.

## What Changes

- Add an optional snapshot accessor that returns a flag's configured evaluation runtime as `/local_evaluation` reports it, with no filtering by the SDK.
- Define when the value is present: for every flag with a loaded local definition that reports the field, whether the value resolved locally or was filled from `/flags`.
- Define when the value is absent: an unknown key, a definition without the field, or a flag with no local definition, because `/flags` does not report the runtime. Absent means unknown; the SDK does not substitute a default.
- Make the read silent, like the payload accessor: no evaluation request, no accessed-key tracking, no `$feature_flag_called`.
- Add matching acceptance scenarios under an `@evaluation_runtime_capable` tag.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: Add the snapshot evaluation runtime accessor and its presence, absence and silence rules.

## Impact

Specs and acceptance documentation only. The accessor is optional, so server SDKs without it remain conformant. posthog-server is the reference implementation.
