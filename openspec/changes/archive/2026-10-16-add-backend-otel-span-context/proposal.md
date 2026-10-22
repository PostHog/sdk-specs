# Proposal

## Why

Backend request context can put a browser session ID on analytics events while leaving application-owned tracing spans without it. Request spans can also start before PostHog reads the headers, so enriching only newly started spans misses the incoming request.

## What Changes

- Define an optional bridge from server request context to application-owned tracing spans.
- Cover the already active request span and child spans created through the documented tracing integration.
- Reuse the native traces contract's `sessionId` and `posthogDistinctId` keys, explicit attribute precedence, and stable context snapshots.
- Require optional dependencies, request isolation, and preservation of application tracing setup.
- Add descriptive acceptance scenarios; do not claim shared adapter execution before bindings exist.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `tracing-headers`: connect extracted request context to application-owned spans through supported optional tracing integration.

## Impact

Server SDK request-context integrations and their optional tracing hooks. SDK-specific method names and supported runtime versions remain documented by each SDK. This does not add a native trace exporter, change event session support, or change AI span processor contracts. Implementation progress is tracked in [#128](https://github.com/PostHog/sdk-specs/issues/128).
