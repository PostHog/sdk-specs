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
  - Automatic instrumentation gives the host a `flush()`, on the handle it returns or, where it
    returns none (posthog-go), on the analytics object the host passes in. It waits for the captures
    started before the call, then flushes the PostHog client. Captures that start while it waits belong to the
    next call, so steady traffic on a shared server cannot hold it open. It never raises or rejects; a
    failed client flush is logged.
  - Where an SDK's PostHog client is itself the MCP wrapper (`PostHogMCP` in posthog-js and
    posthog-python), that client's flush and shutdown wait for its pending MCP captures first.
  - Flushing SHOULD be bounded by a deadline where the language makes that natural; elsewhere the
    platform's wait-until limit bounds it.
  - "The SDK is flushed" in scenarios means this flush.
  - One scenario for each style. Both only flush right after a call, so a harness can set them up in
    every SDK; an SDK with synchronous capture passes the wait trivially.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Observer-only instrumentation**.

## Impact

- posthog-js: `analytics.flush()` conforms (PostHog/posthog-js#5842). Left: `PostHogMCP` inherits
  posthog-node's `flush()` and `shutdown()`, which do not wait for its MCP pipeline. Its events are
  sent today only because that pipeline is microtask-only, the timing #5842 stopped relying on.
- posthog-python: the handle conforms with PostHog/posthog-python#1306. Known gap: `flush()` waits
  only for captures on the event loop it runs on. `PostHogMCP` waits for its captures in `flush()` and
  `shutdown()`; `shutdown()` has no deadline.
- posthog-ruby already conforms on waiting: its sink captures synchronously, so nothing is pending
  when `Analytics#flush` flushes the client. Left: `Analytics#flush` neither rescues a failed client
  flush nor passes `Client#flush`'s `timeout:`.
- posthog-go and posthog-rs offer no MCP flush: posthog-go's `Instrument` returns nothing and
  `posthogmcp.Analytics` has no `Flush`; posthog-rs's `instrument` returns the wrapped server. Both
  need one.
