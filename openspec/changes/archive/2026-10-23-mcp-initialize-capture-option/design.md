## Overview

The option turns off one event. It is a flag on the emit point, not a change to how the SDK observes
the handshake.

## Key Decisions

- Default on, like every other event in the Configuration table.
- With the option off, everything else stays the same. In particular, the SDK still mints the session
  token at `initialize`, so stateless and multi-pod sessions do not fragment.
- The option name says "event", not "capture". SDKs with a manual client already have a method
  that captures `$mcp_initialize` by hand, such as `PostHogMCP.captureInitialize()`.

## Alternatives Considered

- **Drop `$mcp_initialize` from the spec.** Rejected because some hosts read it to count connections.
- **Rely on the before-send hook.** Rejected because the hook runs only after the SDK has built the
  event. A host also has to know the event name to drop it.

## Open Questions

None.
