## ADDED Requirements

### Requirement: Interface identity

Every MCP analytics event, and the `$exception` captured next to a failed call, SHALL carry
`$mcp_interface` naming the interface the call arrived through, set before any before-send hook
runs. Server instrumentation, the scope of this spec, SHALL send `"mcp"`. `"webmcp"` is reserved for
in-page browser tools instrumented by a client SDK and SHALL NOT be sent by an MCP server. `$lib`
("Library identity") names the runtime, not the interface, and SHALL NOT be used in its place.

#### Scenario: Server events name the mcp interface
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_interface" should be "mcp"

#### Scenario: A failed call's exception names the same interface
- **GIVEN** an MCP server instrumented by the SDK with exception autocapture enabled and a tool "search_docs" whose handler throws
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$exception" event's property "$mcp_interface" should be "mcp"
