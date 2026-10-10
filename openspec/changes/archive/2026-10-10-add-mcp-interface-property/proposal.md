## Why

MCP analytics events can come from two different interfaces. A server instrumented by an MCP add-on
package emits them, and so does a browser SDK that instruments in-page WebMCP tools. The browser side
already labels its `$mcp_tool_call` with `$mcp_interface: "webmcp"`, and `@posthog/mcp` now sets
`$mcp_interface: "mcp"` on its events and their `$exception` siblings. The property is not in this
spec, so it is currently sent only because one package chose to, under the clause that permits extra
`$mcp_*` properties. Nothing keeps the next SDK from omitting it, or from spelling the value
differently, which would break the one breakdown that separates the two interfaces.

## What Changes

- Require every MCP analytics event, and the `$exception` captured next to a failed call, to carry
  `$mcp_interface`.
- Fix `"mcp"` as the value for server instrumentation, the scope of this spec.
- Reserve `"webmcp"` for in-page browser tool instrumentation, so no server reuses it.
- Add the property to the property reference table.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: add the `$mcp_interface` property and its values.

## Impact

Additive. SDKs that do not set the property today (posthog-python, posthog-go) gain one constant
string property on each MCP event; no existing property changes. Queries that filter on
`$mcp_source` or `$lib` keep working.
