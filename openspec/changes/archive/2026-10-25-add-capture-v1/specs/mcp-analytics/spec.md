## MODIFIED Requirements

### Requirement: Library identity

MCP events SHALL be identified by their `$mcp_` event name prefix and `$mcp_source`; `$lib` and `$lib_version`
name the SDK client that sent them. An SDK whose MCP instrumentation shares the application's client SHALL
NOT relabel that client, so its MCP events carry the SDK's own `$lib` (`posthog-python`, `posthog-go`,
`posthog-rs`). An SDK MAY instead label a whole client `posthog-<runtime>-mcp`, with `$lib_version` the
version of the package that ships the instrumentation (`posthog-node-mcp` and the `@posthog/mcp` version),
when it documents that MCP analytics needs a dedicated client; where the SDK fixes its identity when the
client first sends (posthog-node 6), it SHALL also document that the instrumentation must be applied before
the client captures. An SDK on legacy capture that labels events one by one MAY keep a `-mcp` `$lib` on its
MCP events only.

#### Scenario: Events name the MCP instrumentation
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_source" should be the string "posthog_mcp_analytics"
