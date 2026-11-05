## ADDED Requirements

### Requirement: Event schema stability

From an SDK's stable release on (`@posthog/mcp` 1.0.0, and the `posthog.mcp` release that declares
it), a release SHALL NOT rename or remove an event or property this spec defines, change its type, or
change which requests emit an event. It MAY add events, properties, and enumerated values, and redact,
cut, or drop values per "Payload privacy" and "Event size bounds". It MAY break these to meet a rule of
this spec it did not meet before, and SHALL say so in its release notes.

#### Scenario: A later release keeps every name, type, and count
- **GIVEN** an MCP server instrumented by one SDK release, and the same server instrumented by a later release
- **WHEN** an MCP client makes the same requests against each
- **AND** the SDK is flushed
- **THEN** the later release should send every event the earlier one sent, as many times
- **AND** every property the earlier release sent should be sent with the same type, unless "Event size bounds" dropped it

## MODIFIED Requirements

### Requirement: Tool call event

The SDK SHALL emit exactly one `$mcp_tool_call` per tool call that reaches a final outcome: a complete
result (`resultType` `"complete"` or absent), a result with `isError: true`, or an exception from the
handler (in Go, a returned error or a panic). These are not final outcomes and SHALL NOT emit:

- an `input_required` result a client receives. The SDK SHOULD emit `$mcp_input_required` ("Optional
  events") instead; the retry that completes the call emits the `$mcp_tool_call`, and its request is
  the one `timestamp` and `$mcp_duration_ms` describe.
- a task handle (`resultType: "task"`, or a 2025-11-25 `CreateTaskResult`), which is never reported as
  a successful call. Where the SDK can observe the task's terminal status being recorded (for example
  by wrapping the framework's task store) and still holds every property the call's `$mcp_tool_call`
  would have carried, computed when the call arrived, and a monotonic start time, it SHOULD emit the
  `$mcp_tool_call` once, with `$mcp_duration_ms` running from that timestamp to the terminal status,
  after the store accepts the terminal status: `completed` takes the task's result, `failed` is a
  failed call with the task's error message, and `cancelled` is a failed call with `$mcp_error_type:
  "cancelled"`. The SDK keeps that context in its own memory, never in the task a client can read.
  Otherwise it SHALL NOT emit for the task.
- a call naming a tool the server has not registered, whether the framework or the server's own
  dispatcher rejects it. Its name is whatever the agent sent, not one of the server's tools, so it is
  not a tool call; the SDK SHOULD emit `$mcp_unknown_tool` instead. A registered tool that is disabled
  is a failed call, and an SDK that cannot tell whether the tool exists (a low-level server with no
  registry it can read) records a failed call. Invalid arguments for a tool that exists are a failed
  call; the SDK SHOULD label it `$mcp_error_type: "validation"` where it can tell, for example when it
  validates arguments itself or recognizes the framework's validation error.

Every property SHALL have the type and limit in "Property reference". Every `$mcp_tool_call` SHALL
carry these properties. Without any one of them a call cannot be counted, attributed to its tool,
timed, or placed in order within its session.

- `$mcp_tool_name`: non-empty.
- `$mcp_is_error`: a JSON boolean, never a string or number.
- `$mcp_duration_ms`: a JSON number of milliseconds from `timestamp` to the final outcome, measured
  with a monotonic clock where the SDK times the call itself, so it is never negative; a duration
  computed from times a caller supplies is clamped to 0.
- `$mcp_source`: `"posthog_mcp_analytics"`.
- `$session_id`: per "Session identity".
- `timestamp`: when the request started, not when the event was sent.

When known, it SHALL also carry `$mcp_tool_description` and `$mcp_tool_category` (a PostHog-defined
`category` key in the tool's `_meta`), read from the server's registered tools rather than only from an
earlier listing, and `$mcp_llm_model` with `$mcp_llm_model_source`. On every event that carries a
model, the model comes from request `_meta` as `"client_metadata"` (the proposed
`io.modelcontextprotocol/aiInvocation` `model`, or a known client key such as `x-codex-turn-metadata`
`model`), else from the `llm_model` argument as `"self_reported"`. A blank or `"unknown"` model SHALL
be omitted with its source; otherwise it is sanitized per "Payload privacy". The SDK SHOULD also set
`$mcp_resource_name` to the tool name. The SDK SHALL NOT emit `$mcp_session_id` unless it equals
`$session_id`, because two session properties with different values would place one call in two
conversations.

#### Scenario: A successful call produces one event with the required properties
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **AND** the SDK is flushed
- **THEN** exactly one event named "$mcp_tool_call" should be sent
- **AND** its property "$mcp_tool_name" should be the string "search_docs"
- **AND** its property "$mcp_is_error" should be the boolean false
- **AND** its property "$mcp_duration_ms" should be a number greater than or equal to 0
- **AND** its property "$mcp_source" should be the string "posthog_mcp_analytics"
- **AND** its property "$session_id" should be a non-empty string

#### Scenario: A result that asks for more input is not counted until the call completes
- **GIVEN** an MCP server instrumented by the SDK with a tool "deploy" that first returns a result with resultType "input_required"
- **WHEN** an MCP client calls tool "deploy"
- **AND** the SDK is flushed
- **THEN** no event named "$mcp_tool_call" should be sent
- **WHEN** the MCP client retries the call with the requested input and the tool returns a complete result
- **AND** the SDK is flushed
- **THEN** exactly one event named "$mcp_tool_call" should be sent

#### Scenario: A call to a tool the server never registered is not counted
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs", whose tool registry the SDK can read
- **WHEN** an MCP client calls tool "no_such_tool" with arguments `{}`
- **AND** the SDK is flushed
- **THEN** no event named "$mcp_tool_call" should be sent

### Requirement: Arguments the SDK injects

The SDK SHALL advertise each of these arguments that is enabled on every tool in `tools/list`, leaving
the registered tool unchanged: `context` (the agent's reason for the call), `llm_model` (the agent's
model), and `conversation_id`. The SDK SHALL:

- leave `conversation_id`, and the `_mcp_instructions` output-schema declaration of "Session
  identity", out of a listing requested by a handle-free client of "Session identity". That client
  names the conversation in `_meta`, so the argument would only add a second, weaker grouping key;

- mark `context` required where it removes it before the MCP framework validates arguments, because
  models fill required arguments, and optional otherwise, so no call is rejected for omitting it.
  `llm_model` SHALL be optional: an agent that does not know its model would otherwise guess one, and
  the model a client sends in `_meta` ("Tool call event") takes precedence anyway. `conversation_id`
  SHALL be optional: the agent has no handle on its first call;
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
personal and identifying information. The injected `context` one SHALL ask for a few words naming the call's
purpose, describing people and entities by role ("a customer"), and SHALL tell the agent not to quote
the user. `$mcp_intent` records why a tool was called. Quoted user text adds the conversation's
content, including names that pattern redaction misses, and says nothing more about the purpose.
This does not apply to the `context` report argument of `get_more_tools` (see "Optional events"),
which holds a report, not a purpose.

#### Scenario: The context argument is advertised, captured, and removed
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs" whose schema declares only "query"
- **WHEN** an MCP client lists tools
- **THEN** the advertised schema for "search_docs" should declare a string property "context"
- **WHEN** the MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find the flags docs"}`
- **AND** the SDK is flushed
- **THEN** the tool handler should receive arguments `{"query": "flags"}`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find the flags docs"
- **AND** its property "$mcp_intent_source" should be "context_parameter"

#### Scenario: Only a handle-free client's listing has no conversation_id argument
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled and a tool "search_docs" whose schema declares only "query"
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" lists tools
- **THEN** the advertised schema for "search_docs" should declare a string property "context"
- **AND** it should not declare a property "conversation_id"
- **WHEN** an MCP client with `User-Agent` "example-client/1.0" lists tools
- **THEN** the advertised schema for "search_docs" should declare a property "conversation_id"
- **WHEN** an MCP client with `User-Agent` "codex-mcp-client/0.50.0" lists tools
- **THEN** the advertised schema for "search_docs" should declare a property "conversation_id"

#### Scenario: A fresh low-level server resolves injected argument ownership
- **GIVEN** automatic instrumentation creates a fresh low-level server for `tools/call`
- **AND** the tool "search_docs" has a strict schema that declares only "query"
- **AND** that server instance has not served `tools/list`
- **AND** a host callback resolves tool "search_docs" to its original schema before SDK injection
- **WHEN** the MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find docs", "llm_model": "model-a"}`
- **THEN** the tool handler should receive arguments `{"query": "flags"}`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find docs"
- **AND** the "$mcp_tool_call" event's property "$mcp_llm_model" should be "model-a"
