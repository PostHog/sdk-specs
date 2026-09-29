## Why

PostHog/sdk-specs#74 recorded the flag evaluation runtime on the `evaluate-flags` snapshot with two surfaces: a per-key accessor (`getEvaluationRuntime(key)`) and a runtime criterion on the snapshot filter (`only(filter)`). In review, dustinbyrne asked to pick one, preferring `only(filter)` because it extends the existing filter API and does not require iterating keys from the caller's end, and noted that the filter's `MAY` makes it optional for the conformance loops, so it has to be `SHALL` if it is meant to exist.

Two surfaces for one use case give SDKs two shapes to converge on and callers two ways to get the same answer. The filter alone covers the use case, bootstrapping a client, in one call.

## What Changes

- The runtime criterion on the snapshot filter becomes the only surface for the evaluation runtime. The spec no longer defines a per-key accessor.
- An SDK that exposes the evaluation runtime SHALL expose the criterion. Exposing the runtime at all stays `MAY`, following the `@payload_default_capable` precedent, because one SDK implements it today.
- The presence, absence and silence rules are unchanged and restated in terms of what the filter matches: the local definition's runtime, kept through a `/flags` fallback; unknown never matches; no evaluation, no network, no access tracking, no `$feature_flag_called`.
- The three accessor scenarios under `@evaluation_runtime_capable` become filter scenarios with the same fixtures. The existing filter scenario is unchanged.
- The reference implementation, PostHog/posthog-android#805, drops the accessor in the same review round.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: the "Snapshot evaluation runtime access" requirement is rewritten around the filter criterion, with no per-key accessor.

## Impact

Specs and acceptance documentation. No SDK has released the accessor, so nothing public is removed.
