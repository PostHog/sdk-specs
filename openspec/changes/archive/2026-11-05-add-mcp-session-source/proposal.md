## Why

A server owner cannot tell from the events whether sessions are grouped or fragmented. On a
stateless HTTP server a call that carries no client conversation id, no handle, and no transport
session gets a session of its own, so the only symptom is sessions that hold one call each. Showing
it takes an inference over every session's call count. Which client sends nothing, and how much of a
server's traffic that is, decides what to fix next: a client row, conversation anchoring, or a
query-time fallback (PostHog/posthog#119784).

## What Changes

- **Session identity**: automatic instrumentation SHOULD set `$mcp_session_source` on every event to
  what produced its `$session_id`: `client_metadata`, `conversation`, `transport`, or `generated`. The
  manual API MAY.
- Two existing scenarios also check the property.
- Property reference gains the row (prose alignment, applied at archive).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Session identity** and the Property reference.

## Impact

One new property on every event from automatic instrumentation. No session id changes. posthog-js
(`@posthog/mcp`) and posthog-python (`posthog.mcp`) implement it alongside the client conversation id
rows (PostHog/posthog-js#5577, PostHog/posthog-python#1193).
