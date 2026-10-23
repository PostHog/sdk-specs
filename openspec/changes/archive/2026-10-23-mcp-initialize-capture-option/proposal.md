## Why

Many MCP clients reconnect before every few tool calls, so `$mcp_initialize` can outnumber
`$mcp_tool_call`. On PostHog's own MCP server it is 37% of all MCP events. Hosts that do not use the
event pay for it and have no way to turn it off. The JavaScript and Python SDKs add an option that
does this.

## What Changes

- Add an initialize capture option, on by default, to the Configuration table.
- Modify the **Optional events** requirement: with the option off, the SDK sends no
  `$mcp_initialize` and changes nothing else.
- Add the `@mcp_initialize_capable` acceptance tag and two scenarios: one event per legacy
  `initialize` by default, and none with the option off while the session holds.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Optional events** requirement and the Configuration table.

## Impact

Nothing changes for a host that keeps the default. A host that turns the option off loses the
handshake event only. Tool calls keep their sessions and client identity.
