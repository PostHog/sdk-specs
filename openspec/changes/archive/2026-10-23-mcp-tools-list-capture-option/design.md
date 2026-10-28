## Overview

The option turns off one event. It is a flag on the emit point, not a change to the listing.

## Key Decisions

- Default on, like every other event in the Configuration table.
- With the option off, the listing stays the same. The SDK still injects `context`, `llm_model`, and
  `conversation_id`, and still lists the virtual tools, because tool calls depend on them.
- The `$exception` of a failed listing goes too. It is part of the listing event.
- The option name says "event", like the initialize event option. SDKs with a manual client already
  have a method that captures `$mcp_tools_list` by hand, such as `PostHogMCP.captureToolsList()`.

## Alternatives Considered

- **Turn off the listing instrumentation too.** Rejected because intent, model capture, and the
  virtual tools depend on it.

## Open Questions

None.
