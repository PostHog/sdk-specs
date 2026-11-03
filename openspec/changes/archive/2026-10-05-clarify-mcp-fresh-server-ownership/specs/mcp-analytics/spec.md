## MODIFIED Requirements

### Requirement: Arguments the SDK injects

The SDK SHALL advertise each of these arguments that is enabled on every tool in `tools/list`, leaving
the registered tool unchanged: `context` (the agent's reason for the call), `llm_model` (the agent's
model), and `conversation_id`. The SDK SHALL:

- mark `context` and `llm_model` required where it removes them before the MCP framework validates
  arguments, because models fill required arguments, and optional otherwise, so no call is rejected
  for omitting them. `conversation_id` SHALL be optional: the agent has no handle on its first call;
- skip injecting an argument into a tool that already declares that name, and skip all three for a
  tool whose root schema uses `$ref`, `oneOf`, `anyOf`, or `allOf` (logging a warning);
- remove injected arguments before the handler runs and keep them out of `$mcp_parameters`;
- treat an argument a server's tool declares itself as the tool's data: pass it through, capture it in
  `$mcp_parameters`, and never read it as intent, model, or handle;
- resolve ownership during `tools/call` from the tool registry or the original tool definition, even
  when the server instance did not serve `tools/list`. If the framework exposes no readable registry,
  automatic instrumentation SHALL provide a host callback that resolves the original tool by name.
  The callback returns the original schema, before SDK injection, in the same form that the host
  advertises it. Ownership learned from a listing on the current instance wins. A missing result or
  callback failure leaves ownership unknown,
  logs the failure, and does not change the MCP response. The SDK strips only arguments that it can
  prove it owns;
- preserve the order and content of the server's tool list otherwise, apart from the
  `_mcp_instructions` output-schema declaration of "Session identity".

A string `context` value becomes `$mcp_intent` (a value that is not a string is omitted) with
`$mcp_intent_source: "context_parameter"`; a server-provided fallback sets `"inferred"`. An empty
intent (blank, or `"{}"`) SHALL be omitted. When a request carries a standardized intent in `_meta`
(such as the proposed `io.modelcontextprotocol/aiInvocation` `userIntent`), the SDK SHOULD prefer it,
with `$mcp_intent_source: "client_metadata"`. The default description of every free-text argument the
SDK advertises (`context`, and the virtual tools' report arguments) SHALL tell the agent to leave out
personal and identifying information, and the `context` one SHALL ask for the call's abstract purpose,
describing people and entities by role ("a customer"), because pattern redaction misses names.

#### Scenario: The context argument is advertised, captured, and removed
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs" whose schema declares only "query"
- **WHEN** an MCP client lists tools
- **THEN** the advertised schema for "search_docs" should declare a string property "context"
- **WHEN** the MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find the flags docs"}`
- **AND** the SDK is flushed
- **THEN** the tool handler should receive arguments `{"query": "flags"}`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find the flags docs"
- **AND** its property "$mcp_intent_source" should be "context_parameter"

#### Scenario: A fresh low-level server resolves injected argument ownership
- **GIVEN** automatic instrumentation creates a fresh low-level server for `tools/call`
- **AND** the tool "search_docs" has a strict schema that declares only "query"
- **AND** that server instance has not served `tools/list`
- **AND** a host callback resolves tool "search_docs" to its original schema before SDK injection
- **WHEN** the MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find docs", "llm_model": "model-a"}`
- **THEN** the tool handler should receive arguments `{"query": "flags"}`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find docs"
- **AND** the "$mcp_tool_call" event's property "$mcp_llm_model" should be "model-a"
