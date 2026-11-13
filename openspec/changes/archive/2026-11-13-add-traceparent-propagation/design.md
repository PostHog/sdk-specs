## Context

`tracing-headers` owns the client-side interception of outgoing application requests. posthog-js reused that same fetch/XHR patching to add a W3C `traceparent`, which is a different kind of header: it is consumed by the application's own tracing backend, not by a PostHog SDK, and it is subject to CORS preflight on cross-origin requests.

## Goals / Non-Goals

**Goals:** Fix the option shape, matching rule, header format, overwrite rule and gating so a second SDK implements the same thing.

**Non-Goals:** Requiring any SDK to ship it, turning it on by default, recording a client span, propagating `tracestate`, or changing the existing PostHog tracing headers.

## Decisions

- A separate target list, not the tracing-header allow-list. Adding an unexpected header to a cross-origin request fails CORS preflight unless the server allows it, so a host that opted into the PostHog headers must not silently start receiving `traceparent`.
- Exact matching, with a scheme-qualified entry pinned to an origin. This follows the capability's existing exact-hostname rule; wildcards would widen the CORS blast radius.
- Never overwrite an application-set `traceparent`. An application that already propagates context owns the trace; replacing the header would split it.
- `MAY`, not `SHALL`. One SDK ships it today. The requirement constrains the shape of the feature wherever it appears rather than mandating the feature.
- The header is sampled (`-01`) and the span id has no recorded span behind it. That is a deliberate trade-off: the server root span gets a parent id that resolves to nothing, which is the cost of propagating without recording a browser span.

## Risks / Trade-offs

- An SDK that later records real client spans must propagate the active span's context instead of a fresh id. The requirement allows that explicitly while holding the format and gate fixed.
- A dangling parent span id may look like data loss in a tracing UI. Documented here as the known consequence of propagation without client spans.

## Migration Plan

Sync and archive this change in the same PR. posthog-js already ships the behavior; no other SDK is required to follow.

## Open Questions

- Whether `tracestate` should be propagated too. Out of scope until an SDK has a client span whose state it would carry.
