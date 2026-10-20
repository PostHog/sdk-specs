## Why

MCP analytics ships in `@posthog/mcp` (posthog-js) and `posthog.mcp` (posthog-python), and Go and Ruby
ports are in progress. The two shipped SDKs agree on most behavior only because they were ported from
each other, and they already diverge in ways that change the numbers the product shows: which
arguments are stripped, whether the `context` argument is required, how `$lib_version` is set, and
whether credentials are detected by entropy. The product reads a small set of `$mcp_*` properties and
assumes their types and meaning (a boolean `$mcp_is_error`, a numeric `$mcp_duration_ms`, a stable
`$session_id`, a non-empty `$mcp_tool_name`). An SDK that breaks one of those assumptions produces
plausible but wrong dashboards, with no error. The 2026-07-28 MCP revision also removed the
`initialize` handshake and protocol sessions and added multi-request tool calls, which no SDK handles
the same way yet.

This change records one contract before more ports inherit today's drift: what each event must carry,
what each property means, which rules the product depends on, and how an SDK proves it conforms.

## What Changes

- New capability spec `mcp-analytics` covering: observer-only instrumentation, the `$mcp_tool_call`
  event and its required properties, failure capture, session identity (conversation anchoring),
  person identity, client and server identity, the arguments the SDK injects (`context` for intent,
  `llm_model`, `conversation_id`), payload capture, manual capture, payload privacy, event size bounds, library
  identity, and optional events.
- New acceptance feature `acceptance/public/mcp-analytics.feature`.
- Not in scope: the product's queries and dashboards, and LLM analytics (`$ai_*` generations, token
  cost).
- Distinct from `capture-ai`: MCP analytics events ride the host client's normal `capture` route under
  its standard limits, and this spec covers an add-on package rather than a core client method.

## Capabilities

### New Capabilities

- `mcp-analytics`: server-side analytics for MCP servers, instrumenting tool calls and related
  requests into `$mcp_*` events with a fixed property contract, conversation-anchored sessions, agent
  intent capture, and payload sanitization.

### Modified Capabilities

None.

## Impact

- `openspec/specs/mcp-analytics/spec.md`: created on archive from this change's delta.
- `openspec/project.md` and the root `README.md` capabilities table gain an `mcp-analytics` entry.
- Adds `acceptance/public/mcp-analytics.feature`. Its steps need an MCP driver route in the SDK
  test harness (separate change in `PostHog/posthog-sdk-test-harness`); until then they report as
  unsupported bindings.
- SDK follow-ups to resolve the divergences listed in design.md's Conformance section happen in the SDK
  repositories.
