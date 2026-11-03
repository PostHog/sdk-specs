## Overview

The SDK must know whether each reserved argument belongs to PostHog or to the tool. High-level
frameworks expose this information through a registry. A fresh low-level server might have only a
call handler, so it needs help from the host.

## Key Decisions

- Resolve ownership during `tools/call`. Do not replay `tools/list`, because listing can have side
  effects or depend on request state.
- Let a host return the original tool definition when the framework has no readable registry. The
  definition must use the same schema form that the host advertises.
- Prefer ownership learned from a listing on the current instance. This keeps one instance
  internally consistent when a callback returns different data.
- Keep three ownership states: tool-owned, SDK-owned, and unknown. Strip only SDK-owned arguments.
- Treat a missing result or callback failure as unknown ownership. Log the failure, but do not let
  it change the MCP response.

## Alternatives Considered

- **Replay `tools/list` during every call.** Rejected because listings can be expensive, paginated,
  stateful, or unavailable on the call path.
- **Always strip reserved arguments.** Rejected because a tool can declare the same argument name.
- **Pass all reserved arguments through.** Rejected because strict schemas reject SDK-owned keys.

## Open Questions

None.
