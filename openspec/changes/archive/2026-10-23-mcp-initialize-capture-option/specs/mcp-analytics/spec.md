## MODIFIED Requirements

### Requirement: Optional events

Every event below SHALL carry the properties of "Client and server identity" and "Session identity",
and SHALL come only from a request the client sent: never from a request the framework dispatches
internally, and never `$mcp_initialize` without an `initialize`. Automatic instrumentation SHOULD emit
`$mcp_input_required` and `$mcp_unknown_tool`, and MAY emit the others; a manual API MAY offer capture
methods for any of them. An SDK declares which of these events it emits as the acceptance capability
tags `@mcp_input_required_capable`, `@mcp_unknown_tool_capable`, `@mcp_tools_list_capable`, and
`@mcp_initialize_capable`, and
whether it observes task stores ("Tool call event") as `@mcp_task_store_capable`. The rules that no
`$mcp_tool_call` is sent for a round, a task handle, or an unknown tool apply to every SDK.

- `$mcp_tools_list` for `tools/list`, with `$mcp_listed_tool_names` as a JSON array of the names on
  that page. It describes the server's catalogue: a `tools/list` request cannot carry a conversation
  handle, so where calls are anchored (no transport session) its `$session_id` does not match
  theirs. Its `$mcp_response` SHALL keep only the result envelope (such as `nextCursor`, `ttlMs`,
  `cacheScope`, `_meta`), never the `tools` array, and is omitted when the envelope is empty; the
  response capture option does not apply to it.
- `$mcp_input_required` for each `input_required` result a client receives: `$mcp_tool_name`,
  `$mcp_duration_ms` for that round, and `$mcp_input_request_methods`, never the requests' or answers'
  content. It records every round, including rounds whose call never completes. Not rounds: a round a
  framework shim fulfils for a legacy client (any `input_required` returned for a legacy-revision
  request), in-call elicitation on legacy revisions, and a task's own `input_required` status. For a
  shim, the SDK keys the handler's re-entries on the transport session and the client's JSON-RPC
  request id, takes the call's `timestamp` from the first, and emits once when a re-entry returns a
  final outcome. A sequence the framework ends without one (a round cap, a timeout, or a disabled shim)
  is a failed call with `$mcp_error_type: "input_required"` where the SDK can observe it; otherwise its
  state is evicted with the session's.
- `$mcp_unknown_tool` for a call that names a tool the server does not have (see "Tool call event"),
  with the requested name as `$mcp_tool_name`; a call naming no tool emits nothing. It records what the
  agent looked for and did not find.
- `$mcp_missing_capability` from the SDK's `get_more_tools` virtual tool and `$mcp_feedback` from its
  `send_feedback` virtual tool (names configurable). `get_more_tools` declares a required `context`
  argument, the agent's report, which becomes `$mcp_intent`. `send_feedback` declares `feedback_type`
  and `summary` (required), and `details`, `friction_points`, `suggested_improvement`, `tool_name`,
  `sentiment`, and `task_completed`; they become the `$mcp_feedback_*` properties of "Property
  reference" (`tool_name` as `$mcp_feedback_tool`), and the non-empty of `summary` and `details`,
  joined by a blank line (`"\n\n"`), become `$mcp_intent`. Both use `$mcp_intent_source:
  "context_parameter"`. Neither event carries `$mcp_parameters`, because the report is free text that
  only the free-text pass sanitizes for personal data. A report argument the host declares becomes
  `$mcp_feedback_<name>`; the SDK SHALL reject at configuration one whose property a built-in field
  uses (`type`, `tool`, `summary`, ...) or that reuses an injected argument's name, SHALL NOT capture
  arguments the tool does not declare, and SHALL send the event even when the host's report handler
  fails.
- `$mcp_initialize` for a legacy `initialize`, unless the host turns the initialize event option
  off (see "Configuration"). With the option off, the SDK SHALL NOT send `$mcp_initialize`, and SHALL
  change nothing else: the session token, `$session_id`, and the client and server identity of later
  events stay the same.
- `$mcp_resource_read` and `$mcp_resources_list` for resource requests. `$mcp_resource_read` SHALL
  NOT carry the resource's contents.

A virtual tool SHALL NOT be advertised when the server already registers a tool of that name. It gets
every enabled injected argument except `context`, whose place its own report arguments take, follows
"Session identity" like any tool call, and emits its own event, not `$mcp_tool_call`.

#### Scenario: A tool listing keeps names and only the result envelope (@mcp_tools_list_capable)
- **GIVEN** an MCP server instrumented by the SDK with 101 tools and a page size of 100
- **WHEN** an MCP client lists tools
- **AND** the SDK is flushed
- **THEN** the "$mcp_tools_list" event's property "$mcp_listed_tool_names" should be an array of the 100 tool names on the first page
- **AND** its property "$mcp_response" should include "nextCursor"
- **AND** its property "$mcp_response" should not include "tools"

#### Scenario: Each legacy initialize sends one $mcp_initialize (@mcp_initialize_capable)
- **GIVEN** an MCP server instrumented by the SDK with default options
- **WHEN** an MCP client on protocol revision "2025-11-25" sends `initialize`
- **AND** the SDK is flushed
- **THEN** exactly one "$mcp_initialize" event should be sent

#### Scenario: With the initialize event option off, no $mcp_initialize is sent and the session holds (@mcp_initialize_capable)
- **GIVEN** a stateless HTTP MCP server instrumented by the SDK with the initialize event option off
- **WHEN** an MCP client on protocol revision "2025-11-25" sends `initialize`
- **AND** calls tool "search_docs" with the session token from the `initialize` response
- **AND** the SDK is flushed
- **THEN** no "$mcp_initialize" event should be sent
- **AND** the "$mcp_tool_call" event's "$session_id" should equal the session in that token
