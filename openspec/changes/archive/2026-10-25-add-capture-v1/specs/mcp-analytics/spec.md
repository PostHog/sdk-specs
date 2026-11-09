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

### Requirement: Event size bounds

Every MCP event's properties, `$set` and `$groups` included, SHALL serialize to at most 102,400 bytes
of compact UTF-8 JSON, without ever dropping the event or a required property of "Tool call event". The
bound covers the properties the MCP instrumentation builds; values the client adds afterwards from its
global or context layers (`capture`) are outside it, and capture's own event size limit applies to them. The
SDK SHALL shrink `$mcp_response` and `$mcp_parameters` first and other optional properties after them.
To shrink is to truncate string values to a smaller cap of the SDK's choosing, keeping their start, and
to drop the property only when it still does not fit; the order is normative, the caps are not;
`$mcp_error_message` is truncated, never dropped. The SDK SHOULD bound them in one pass (apply the
limits of "Property reference" first, then measure) rather than re-serializing repeatedly.

#### Scenario: A very large response still produces a bounded event
- **GIVEN** an MCP server instrumented by the SDK with a tool "export" that returns a 2 MB text block
- **WHEN** an MCP client calls tool "export"
- **AND** the SDK is flushed
- **THEN** exactly one event named "$mcp_tool_call" should be sent
- **AND** its serialized properties should be at most 102400 bytes
- **AND** it should have properties "$mcp_tool_name", "$mcp_is_error", "$mcp_duration_ms", and "$session_id"
