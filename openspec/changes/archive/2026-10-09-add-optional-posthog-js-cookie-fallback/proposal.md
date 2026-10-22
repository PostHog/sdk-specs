## Why

Server SDKs link backend events to a browser session only through the `X-POSTHOG-*` tracing headers, and those exist only when the frontend sets `tracing_headers` for the backend hostname. Most apps never set it. With its default `localStorage+cookie` persistence, posthog-js already writes the distinct id, the session id and the user state to a first-party cookie, and the browser sends that cookie on every same-site request. posthog-python ([#1045](https://github.com/PostHog/posthog-python/pull/1045)) and posthog-node ([posthog-js #5270](https://github.com/PostHog/posthog-js/pull/5270)) add an off-by-default option that reads it. The spec lists only headers as server input.

## What Changes

- Add a requirement for an optional, off-by-default posthog-js cookie fallback in server request middleware: project-scoped cookie name, consent cookie and opt-out-by-default handling, identified-only distinct id, session liveness checks with a clamped idle timeout, headers-only when any header is present, and no use for authentication.
- Add the cookie to the server-side state read, and a Behavior item that points to the requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `tracing-headers`: allow an optional server-side cookie fallback.

## Impact

The option is optional and off by default, so SDKs without it stay conforming. posthog-python and posthog-node implement it in the linked PRs.
