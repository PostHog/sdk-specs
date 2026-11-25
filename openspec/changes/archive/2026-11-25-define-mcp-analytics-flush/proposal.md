## Why

"Observer-only instrumentation" says a server that lives for a single request SHALL let the host flush
without delaying the response. It does not say what flushing does, so each SDK chose differently:

- posthog-python's `McpAnalytics.flush()` only waited for captures still in the MCP pipeline. The host
  also had to call `posthog.flush()`, or the events were lost.
- posthog-ruby's `Analytics#flush` only flushes the PostHog client.
- posthog-js's `analytics.flush()` (PostHog/posthog-js#5842) does both: it waits for pending captures,
  then flushes the client.

Waiting alone is not enough: the events still sit in the client's queue when the runtime freezes.
Flushing the client alone is not enough where capture is asynchronous: in posthog-js an event reaches
`posthog.capture()` only after sanitizing and the before-send hook, which can finish after the
response is built, so a client flush right after the request can run before the event is queued.
posthog-js and posthog-python (PostHog/posthog-python#1306) now both do both. The spec should record
that, so `flush()` means the same in every SDK.

## What Changes

- **Observer-only instrumentation** defines flushing:
  - The handle automatic instrumentation returns exposes `flush()`. It waits for the captures started
    before the call, then flushes the PostHog client. Captures that start while it waits belong to the
    next call, so steady traffic on a shared server cannot hold it open. It never raises or rejects; a
    failed client flush is logged.
  - Where an SDK's PostHog client is itself the MCP wrapper (posthog-js's `PostHogMCP`), that client's
    flush and shutdown wait for its pending MCP captures first.
  - Flushing SHOULD be bounded: by a deadline where the language makes that natural, or else by the
    platform's wait-until limit.
  - One scenario for each style.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Observer-only instrumentation**.

## Impact

- posthog-js: `analytics.flush()` conforms (PostHog/posthog-js#5842). Left: `PostHogMCP` inherits
  posthog-node's `flush()` and `shutdown()`, which do not wait for captures still in its MCP pipeline.
- posthog-python: conforms with PostHog/posthog-python#1306. Known gap: `flush()` waits only for
  captures on the event loop it runs on.
- posthog-ruby already conforms. Its sink captures synchronously, so nothing is pending when
  `Analytics#flush` flushes the client.
- posthog-go and posthog-rs: check their flush against the new rule.
