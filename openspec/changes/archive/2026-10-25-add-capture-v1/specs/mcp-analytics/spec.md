## MODIFIED Requirements

### Requirement: Library identity

MCP events SHALL be identified by their `$mcp_` event name prefix and `$mcp_source`, and SHALL carry `$lib`
as `posthog-<runtime>-mcp` (such as `posthog-node-mcp`, `posthog-python-mcp`, `posthog-rs-mcp`,
`posthog-go-mcp`) with `$lib_version` the version of the installed package that ships the instrumentation.
The SDK SHOULD label MCP events one by one, as an integration label (`capture`, **Events name their own
library**), so events the host application captures through the same client keep the SDK's own `$lib`. Where
the platform can only label the whole client, the SDK MAY label a dedicated client `posthog-<runtime>-mcp`
and SHALL document that MCP analytics needs a dedicated client. A `$lib` in the call's `properties`, and
`before_send`, win over the label.

#### Scenario: Events name the MCP instrumentation
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_source" should be the string "posthog_mcp_analytics"
- **AND** the "$mcp_tool_call" event's property "$lib" should end with "-mcp"
