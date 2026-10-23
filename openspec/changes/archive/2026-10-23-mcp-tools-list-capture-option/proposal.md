## Why

Many MCP clients list tools on every reconnect, so `$mcp_tools_list` is about as common as
`$mcp_tool_call`. On PostHog's own MCP server it is 30% of all MCP events. Hosts that do not use the
event pay for it and have no way to turn it off. The JavaScript and Python SDKs add an option that
does this.

## What Changes

- Add a tools list capture option, on by default, to the Configuration table.
- Modify the **Optional events** requirement: with the option off, the SDK sends no
  `$mcp_tools_list`, nor the `$exception` of a failed listing, and changes nothing else.
- Add a scenario: with the option off, a listing sends no event and keeps its injected arguments.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Optional events** requirement and the Configuration table.

## Impact

Nothing changes for a host that keeps the default. A host that turns the option off loses the
listing event only. Discovery rates that read `$mcp_listed_tool_names` have no data for that server.
