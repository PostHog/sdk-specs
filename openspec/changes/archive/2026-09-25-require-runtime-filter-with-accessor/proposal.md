## Why

PostHog/sdk-specs#74 added the snapshot evaluation runtime to `evaluate-flags` with two surfaces: a per-key accessor (`getEvaluationRuntime(key)`) and a runtime criterion on the snapshot filter (`only(filter)`). The review on that PR (dustinbyrne) made two points after it merged:

- Pick one surface, preferably `only(filter)`, because it extends the existing filter API and callers do not have to iterate keys themselves.
- The filter is written as `MAY`, so a conformance loop cannot require it. If it must exist, the spec has to say `SHALL`.

The requirement as merged puts the accessor first and the filter last as an optional extra, which is the reverse of how a caller uses them. PostHog/posthog-android#805, the reference implementation, ships both.

## What Changes

- Make the runtime criterion on the snapshot filter mandatory for any SDK that exposes the evaluation runtime. `MAY also expose` becomes `SHALL expose`.
- Reorder the requirement so the filter is the primary surface for bootstrapping a client, and the accessor is the primitive the filter is defined on.
- Keep the accessor. It is the only way to tell an unknown runtime from a known one, and the only way to keep flags with an unknown runtime, which the filter drops by design.
- Keep the outer `MAY`: exposing the evaluation runtime at all stays optional, following the `@payload_default_capable` precedent, because one SDK implements it today.
- No new acceptance scenarios. The four `@evaluation_runtime_capable` scenarios already cover the accessor and the filter.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: the "Snapshot evaluation runtime access" requirement makes the filter criterion mandatory alongside the accessor and reorders the two.

## Impact

Specs only. An SDK that exposes the accessor without the filter criterion becomes non-conformant; posthog-server (PostHog/posthog-android#805) already exposes both, and no other server SDK exposes either yet.
