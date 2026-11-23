## Why

`$session_id` should mean one conversation: one person, in one chat, using an agent that calls the
server. "Session identity" ranks the clues for that, best first: the client's own conversation id,
then the agent's handle, then the transport, then nothing. Two things the SDKs already do are not in
it, and a third is unspecified.

- **posthog-js has a session resolver** (PostHog/posthog-js#5597, the `sessionId` option). It lets a
  server name each request's session itself, for servers that already track sessions their own way.
  The spec does not mention it, so its place in the ranking was undecided: posthog-js#5577 had to
  pick one, and another SDK could pick differently.
- **Its sessions report as `"transport"`** in `$mcp_session_source`, so the data cannot tell a session
  the server chose from a real `Mcp-Session-Id`.
- **Custom events captured inside a tool call have no rule.** posthog-js and posthog-python both read
  the server instance's last session for them. On a shared stateless HTTP server, a custom event then
  took another caller's session and person (PostHog/posthog-js#5740 and PostHog/posthog-python#1193
  review findings).

## What Changes

- **Session identity**:
  - A server's session resolver, where an SDK offers one, comes first: a non-empty value it returns is
    the session key, derived like a handle, and the numbered rules do not apply. The server is the one
    that knows what a session means for its product, and the resolver receives the request, so a
    server that wants per-chat grouping can return the client's conversation id itself. A server
    without a resolver keeps today's ranking. Resolver values SHOULD be ASCII, since the SDKs read
    characters differently past it.
  - The resolver leaves conversation anchoring alone: handles are still minted and recorded, as
    posthog-js does today. A server that does not want them turns anchoring off.
  - `$mcp_session_source` gains `"host"` for a resolver's session.
  - A custom event captured while a tool call runs, including from work the handler started, carries
    that call's session and source, even when other requests overlap on the same instance. It SHOULD
    carry the call's identity and never one from another session. A custom event outside any call
    carries the session the instance last held, never a resolver's, client id's or handle's.
  - Two new scenarios.
- Configuration and the Property reference gain the session resolver row (automatic instrumentation
  only) and the `"host"` value (prose alignment, applied at archive).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Session identity**, Configuration, and the Property reference.

## Impact

- posthog-js already ranks its resolver first and keeps in-tool custom events in their call's session
  and identity (PostHog/posthog-js#5577 and #5740). Left to align: report `"host"`, count a resolver
  call as activity for the one-client connection's 30-minute rotation, and carry the resolver's
  session in a minted token's `sid`.
- posthog-python keeps in-tool custom events in their call's session (PostHog/posthog-python#1193).
  Left: resolve the call's identity before the tool body runs, so those events carry it. It has no
  session resolver; offering one is optional.
- posthog-go, posthog-ruby, posthog-rs: in-tool custom events per the new rule.
