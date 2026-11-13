## Why

`tracing-headers` covers the PostHog correlation headers a client SDK injects into outgoing application requests, and says explicitly that this is "not a distributed tracing ... mechanism". posthog-js has now shipped a second, separate header on the same interception path, and the spec records nothing about it:

- [posthog-js#5675](https://github.com/PostHog/posthog-js/pull/5675) adds the browser config `trace_propagation_targets`, which injects a freshly generated W3C `traceparent` into requests to listed targets so a backend trace can be continued from the browser request.

The `traces` capability anticipated this (`traceparent` auto-injection was left to a later proposal, with the note that it "MUST be allowlist-gated when it ships; shape it consistently"), but no spec fixes the option's shape, the matching rule, the header format, or the CORS-safety constraint. The next SDK to add it has nothing to copy, and the existing wording suggests the capability excludes it.

## What Changes

- Add three requirements to `tracing-headers` for optional client-side W3C `traceparent` propagation: a separate opt-in target list, exact origin/hostname matching with live target updates and fail-open behavior, and a fresh `00-<trace id>-<span id>-01` header per matching request that never overwrites one the application set.
- Record the shape in the capability's header table and configuration surface.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `tracing-headers`: add optional W3C `traceparent` propagation alongside the PostHog correlation headers.

## Impact

Only `openspec/specs/tracing-headers/spec.md` changes. The requirement is permissive (`MAY` offer the feature) and off by default, so no SDK that lacks it becomes non-conformant, and no existing behavior changes. posthog-js is the reference implementation; the browser records no span of its own, so this does not make `tracing-headers` a tracing pipeline.
