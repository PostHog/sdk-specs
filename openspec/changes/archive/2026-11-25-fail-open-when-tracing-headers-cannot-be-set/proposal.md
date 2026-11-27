## Why

The client-side behavior list says injection must "fail open", but no requirement states it, and
nothing says what the SDK does when only part of the header set can be written. A distinct id is
caller-supplied: `identify()` accepts any string, while a browser `Headers` value must be Latin-1.
In posthog-js that combination broke the application's own requests — `xhr.open()` threw from
outside any `try`, and a `fetch(Request)` was rejected because the wrapper had already consumed
its body — and an earlier fix that sent the session and window headers alone left the server with
a session it could not attach to a person.

## What Changes

- **Added: "Client injection fails open and keeps the request intact".**
  - Header preparation that fails SHALL send the application's request unchanged and SHALL NOT
    throw. A value the platform cannot carry as a header is such a failure.
  - When the current distinct id cannot be a header value, the SDK SHALL omit every PostHog
    tracing header for that request, not just the distinct-id header.
  - A copy of the caller's request object built to set headers on SHALL be sent even when
    preparation fails, because building it consumed the caller's body.
  - W3C `traceparent` propagation is independent and unaffected.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `tracing-headers`: one added requirement, stating the fail-open rule the behavior list already
  describes and the all-or-nothing rule for an unwritable header value.

## Impact

- **posthog-js:** matches the shipped behavior (PostHog/posthog-js#5805).
- Other client SDKs that inject tracing headers (iOS/Android interceptors, React Native) need the
  same all-or-nothing rule wherever their HTTP stack can reject a header value.
- No new public API, no new headers, no change for a distinct id the platform can send.
