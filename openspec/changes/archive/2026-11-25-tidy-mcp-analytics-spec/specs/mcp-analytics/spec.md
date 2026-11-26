## RENAMED Requirements

- FROM: `### Requirement: Virtual tool annotations`
- TO: `### Requirement: Virtual tools`

## MODIFIED Requirements

### Requirement: Observer-only instrumentation

An SDK SHALL let a server be instrumented with one call taking the MCP server and a configured PostHog
client. Instrumentation SHALL NOT change what the server returns, apart from the injected arguments of
"Arguments the SDK injects", the conversation handle of "Conversation anchoring", the session token of
"Session identity", and the virtual tools of "Virtual tools". A failure inside instrumentation (an exception, a panic, a
serialization error, an unreachable PostHog endpoint) SHALL NOT change the response or reach the tool
handler or the MCP client.

Instrumentation SHALL NOT add avoidable latency to the response: sanitizing, truncating, and
serializing an event SHOULD happen after the response is handed to the transport, and sending SHALL use
the host SDK's asynchronous capture. State kept per session (identity, advertised schemas, pending
tasks) SHALL be bounded by count, for example a least-recently-used cache, so a long-lived server with
many conversations does not grow without limit. On a server that lives for a single request, the SDK
SHALL let the host flush without delaying the response (for example through the platform's wait-until
hook).

Flushing means every event captured so far is sent, including events still being sanitized or passed
through the before-send hook when the host asks:

- Automatic instrumentation SHALL give the host a `flush()`, following platform idiom: on the handle
  it returns, or on the analytics object the host passes in where it returns none. It SHALL wait until
  every capture started before the call has been handed to the PostHog client or dropped, then flush
  the PostHog client. Captures that start while it waits belong to the next call, so steady traffic on
  a shared server cannot hold it open. `flush()` SHALL NOT raise or reject: a failed client flush is
  logged. Without a working client it completes at once.
- Where the SDK's PostHog client is itself the MCP wrapper (such as posthog-js's `PostHogMCP`), that
  client's flush and shutdown SHALL first wait for its pending MCP captures the same way.
- Flushing SHOULD be bounded by a deadline where the language makes that natural (a timeout argument,
  a context, a cancellable future). Elsewhere the platform's wait-until limit bounds it.

An SDK whose capture is synchronous already has nothing pending, so flushing the client satisfies the
wait. In scenarios, "the SDK is flushed" means this flush.

#### Scenario: A tool result reaches the client unchanged
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled and a tool "search_docs" that returns the text "Found 3 results"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **THEN** the client should receive a result whose content is exactly one text block "Found 3 results"
- **AND** the result should not be marked as an error

#### Scenario: Instrumentation's flush right after a call sends that call
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **AND** the host calls instrumentation's `flush()` as soon as the client receives the result
- **THEN** by the time `flush()` completes, exactly one event named "$mcp_tool_call" should be sent
- **AND** its property "$mcp_tool_name" should be the string "search_docs"

#### Scenario: A client wrapper's shutdown right after a call sends that call
- **GIVEN** an SDK client that is itself the MCP wrapper
- **WHEN** the host records a call to tool "search_docs" through it
- **AND** the host shuts the client down right after
- **THEN** by the time shutdown completes, exactly one event named "$mcp_tool_call" should be sent
- **AND** its property "$mcp_tool_name" should be the string "search_docs"

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
carry the properties that table marks required, and `timestamp`. Without any one of them a call cannot
be counted, attributed to its tool, timed, or placed in order within its session. `timestamp` is when
the request started, not when the event was sent. `$mcp_duration_ms` runs from `timestamp` to the final
outcome, measured with a monotonic clock where the SDK times the call itself, so it is never negative;
a duration computed from times a caller supplies is clamped to 0.

When known, it SHALL also carry `$mcp_tool_description` and `$mcp_tool_category` (a PostHog-defined
`category` key in the tool's `_meta`), read from the server's registered tools rather than only from an
earlier listing, and `$mcp_llm_model` with `$mcp_llm_model_source` (see "Arguments the SDK injects").
The SDK SHOULD also set
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

### Requirement: Session identity

Every MCP event SHALL carry a non-empty `$session_id` that groups one agent conversation as far as the
transport allows. A server that configured a session resolver (see "Configuration") decides this
itself: when the resolver returns a non-empty string for a request, the SDK derives `$session_id` from
that string as below, and the numbered rules do not apply; anything else, or a throw, falls through to
them. Only automatic instrumentation offers a resolver, and an SDK MAY leave it out. The server knows
what a session means for its product, and the resolver receives the request, so it can still return a
client conversation id itself; whatever it returns, including one value for many clients, is its
choice. The numbered rules never group requests from different clients. The session comes from whoever groups the client's calls,
first match wins:

1. The client: a client conversation id (see "Client conversation ids") in the tool call's `_meta`.
2. The agent: a conversation handle (see "Conversation anchoring"), echoed by the agent or minted for this call and
   delivered in its result.
3. The transport: a transport session.
   - An id: a legacy `Mcp-Session-Id` that decodes as a PostHog session token gives its `sid` unchanged;
     any other id is derived as below. An id the framework assigns afresh to every request is not a
     transport session.
   - A one-client connection: the SDK generates a `ses_<UUIDv7>` when the connection opens (for stdio,
     when the process starts) and uses it for every request on that connection. A new connection gets a
     new one, and so does the first tool call that arrives 30 minutes or more after the previous tool
     call on that connection ended, because a desktop app can keep one stdio process alive across many
     separate chats. Every event of a call uses the id resolved when the call arrived.
4. Nobody: a stateless HTTP request carrying none of these gets a fresh `ses_<UUIDv7>` of its own.

A derived `$session_id` is `"ses_" + H(x) + H(x + "::salt")`. `H` runs two 32-bit FNV-1a lanes over the
input's characters (ASCII, so bytes, UTF-16 units, and code points agree), seeds `0x84222325` and
`0xcbf29ce4`, primes `0x1b3` and `0x193`, each step `lane = (lane XOR c) * prime mod 2^32`, and returns
the two lanes as 8 lowercase hex digits each. Derivation is deterministic so replicas, restarts, and
SDKs in different languages agree. A resolver value SHOULD be ASCII for the same reason: the SDKs read a
string's characters differently past ASCII.

Automatic instrumentation SHOULD set `$mcp_session_source` on every event to what produced its
`$session_id`: `"host"` for a session resolver, `"client_metadata"` for a client conversation id (rule 1), `"conversation"` for a
conversation handle (rule 2), `"transport"` for a transport session id or a replayed PostHog session
token (rule 3), and `"generated"` for an id the SDK generated itself, whether for a one-client
connection (rule 3) or a single request (rule 4). An event the SDK sends outside a request, such as a
server's custom event, takes the source of the session it carries. The manual API MAY set it. A server
reads fragmentation from it directly: calls whose source is `"generated"` on a stateless HTTP server
are grouped by nothing.

A custom event the server captures while a tool call runs, from its handler or from work the handler
started, SHALL carry the `$session_id` and `$mcp_session_source` that call resolved when it arrived,
even when other requests reach the same server instance meanwhile. It SHOULD carry the identity resolved
for that call (see "Person identity"), and SHALL NOT carry one resolved for a request in another session.
A custom event captured outside any call carries the session the server instance last held, which is
never one a session resolver, a client conversation id, or a handle produced.

A legacy stateless HTTP server handles each request on a fresh instance, so the SDK MAY carry the
client's session in the `Mcp-Session-Id` of the `initialize` response, which the client replays: a
PostHog session token, the unpadded base64url of the compact JSON object
`{"sid":<session id>,"cn":<client name>,"cv":<client version>,"pv":<protocol revision>}`, where only
`sid` is required. It SHALL NOT mint a token for a 2026-07-28 request or when the request or transport
already carries a session, and SHALL return it only in that response, never store it on transport state
other clients share. A token is at most 4,096 characters, and base64 padding is accepted when decoding;
a value that does not decode to an object whose `sid` is a non-empty string of at most 128 characters
is not a token.

#### Scenario: A session resolver outranks a client conversation id
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled and a session resolver that returns "tenant-42" for every request
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": "v1/conv-example-0001"}
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should be "ses_49f24de273ad14bdc3c6e16273c81fd9"
- **AND** its "$mcp_session_source" should be "host"

#### Scenario: A custom event captured during a call keeps that call's session while another call runs
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled, served over stateless HTTP by one instance shared by every client, whose tool "search_docs" waits for a signal and then captures custom event "docs_searched"
- **WHEN** an MCP client calls tool "search_docs" with `Mcp-Session-Id` set to the PostHog session token `{"sid":"ses_first"}`
- **AND** while that call waits, another MCP client calls tool "search_docs" with no session, and that call is signalled and finishes
- **AND** the first call is signalled and finishes
- **AND** the SDK is flushed
- **THEN** each "docs_searched" event should have the "$session_id" of the "$mcp_tool_call" event of the same call
- **AND** the first call's "docs_searched" event's "$session_id" should be "ses_first"

#### Scenario: Session ids derive identically across SDKs
- **GIVEN** a conversation handle "0190f0e8-7a6b-7c3d-9e4f-5a6b7c8d9e0f"
- **WHEN** the SDK derives a session id from it
- **THEN** the result should be "ses_6df45f0102a182bcd5e8dd5dad6c65a0"

### Requirement: Arguments the SDK injects

The SDK SHALL advertise each of these arguments that is enabled on every tool in `tools/list`, leaving
the registered tool unchanged: `context` (the agent's reason for the call), `llm_model` (the agent's
model), and `conversation_id`. The SDK SHALL:

- leave `conversation_id`, and the `_mcp_instructions` output-schema declaration of "Conversation
  anchoring", out of a listing requested by a handle-free client (see "Client conversation ids"). That
  client names the conversation in `_meta`, so the argument would only add a second, weaker grouping key;

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
  `_mcp_instructions` output-schema declaration of "Conversation anchoring".

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
This does not apply to the `context` report argument of `get_more_tools` (see "Virtual tools"),
which holds a report, not a purpose.

On every event that carries a model, the model comes from request `_meta` as `"client_metadata"` (the proposed
`io.modelcontextprotocol/aiInvocation` `model`, or a known client key such as `x-codex-turn-metadata`
`model`), else from the `llm_model` argument as `"self_reported"`. A blank or `"unknown"` model SHALL
be omitted with its source; otherwise it is sanitized per "Payload privacy".

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

### Requirement: Optional events

Every event below SHALL come only from a request the client sent: never from a request the framework dispatches
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
  With the tools list event option off (see "Configuration"), the SDK SHALL NOT send
  `$mcp_tools_list`, nor the `$exception` of a failed listing, and SHALL change nothing else: the
  listing keeps its injected arguments and virtual tools.
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
- `$mcp_missing_capability` and `$mcp_feedback` from the virtual tools of "Virtual tools".
- `$mcp_initialize` for a legacy `initialize`, unless the host turns the initialize event option
  off (see "Configuration"). With the option off, the SDK SHALL NOT send `$mcp_initialize`, and SHALL
  change nothing else: the session token, `$session_id`, and the client and server identity of later
  events stay the same. The SDK SHALL NOT send an `$exception` for a failed `initialize`, with the
  option on or off.
- `$mcp_resource_read` and `$mcp_resources_list` for resource requests. `$mcp_resource_read` SHALL
  NOT carry the resource's contents.

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

#### Scenario: With the tools list event option off, a listing sends no $mcp_tools_list and keeps injected arguments (@mcp_tools_list_capable)
- **GIVEN** an MCP server instrumented by the SDK with the tools list event option off and a tool "search_docs"
- **WHEN** an MCP client lists tools
- **AND** calls tool "search_docs" with arguments `{"query": "flags", "context": "find flag docs"}`
- **AND** the SDK is flushed
- **THEN** no "$mcp_tools_list" event should be sent
- **AND** the listed "search_docs" input schema should include `context`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find flag docs"

### Requirement: Virtual tools

The SDK SHALL NOT advertise a virtual tool, a tool it adds itself, when the server already registers a
tool of that name. There are two (names configurable): `get_more_tools`, whose call emits
`$mcp_missing_capability`, and `send_feedback`, whose call emits `$mcp_feedback`; both events are
optional events (see "Optional events"). `get_more_tools` declares a required `context`
argument, the agent's report, which becomes `$mcp_intent`. `send_feedback` declares `feedback_type`
and `summary` (required), and `details`, `friction_points`, `suggested_improvement`, `tool_name`,
`sentiment`, and `task_completed`; they become the `$mcp_feedback_*` properties of "Property
reference" (`tool_name` as `$mcp_feedback_tool`), and the non-empty of `summary` and `details`,
joined by a blank line (`"\n\n"`), become `$mcp_intent`. Both use `$mcp_intent_source:
"context_parameter"`. Neither event carries `$mcp_parameters`, because the report already becomes the
`$mcp_feedback_*` properties and `$mcp_intent`. A report argument the host declares becomes
`$mcp_feedback_<name>`; the SDK SHALL reject at configuration one whose property a built-in field
uses (`type`, `tool`, `summary`, ...) or that reuses an injected argument's name, SHALL NOT capture
arguments the tool does not declare, and SHALL send the event even when the host's report handler
fails.

A virtual tool gets every enabled injected argument except `context`, whose place its own report
arguments take, follows "Session identity" and "Conversation anchoring" like any tool call, and emits
its own event, not `$mcp_tool_call`.

The SDK SHALL advertise each virtual tool with the annotations `readOnlyHint: false`,
`destructiveHint: false`, `idempotentHint: false`, and `openWorldHint: false`, and SHALL NOT let host
configuration change them. A call sends one event to the server owner's PostHog project, so it
writes data outside the conversation. It deletes and overwrites nothing. Each repeated call sends
another event. It reaches only that project, not open-ended external entities.

#### Scenario: The missing-capability tool declares that it records data (@mcp_missing_capability_capable)
- **GIVEN** an MCP server instrumented by the SDK with the missing-capability tool enabled
- **WHEN** an MCP client lists tools
- **THEN** the advertised "get_more_tools" tool should have annotations {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false}

#### Scenario: The feedback tool declares that it records data (@mcp_feedback_capable)
- **GIVEN** an MCP server instrumented by the SDK with the feedback tool enabled
- **WHEN** an MCP client lists tools
- **THEN** the advertised "send_feedback" tool should have annotations {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false}

## ADDED Requirements

### Requirement: Client conversation ids

The SDK SHALL read a row's key only from a request that row's recognition rule recognizes, so an
unprefixed key such as `sessionId` is read only from the client that defines it. This table lists every
key the SDK reads for a client conversation id, and a request comes from a recognized client when it
matches a row's recognition rule:

| Client | `_meta` key | Value | Recognized client when | Handle |
|--------|-------------|-------|------------------------|--------|
| ChatGPT | `openai/session` | 1 to 128 printable ASCII characters (0x20 to 0x7E) | the HTTP `User-Agent` matches `^openai-mcp/[^\s(]*\s*\(\s*chatgpt\s*[;,)]`, ignoring case | none |
| OpenAI Codex | `sessionId` | a UUID | the HTTP `User-Agent` starts with `codex-mcp-client/`, or the client name is `codex-mcp-client` | fallback |
| VS Code | `vscode.conversationId` | a UUID | the HTTP `User-Agent` starts with `Visual Studio Code/` or `Visual Studio Code - Insiders/`, or the client name is `Visual Studio Code` or `Visual Studio Code - Insiders` | fallback |

The client name is `$mcp_client_name` as "Client and server identity" resolves it for the request.
Every recognition rule ignores case. Rows are checked in table order, and the first row that
recognizes a request is its client's row: the SDK reads only that row's key and applies only that
row's Handle. A UUID is 32 hexadecimal digits in the 8-4-4-4-12 hyphenated form, of any version, compared and derived
lowercased; the nil UUID (all zeros) is not one.

So `openai-mcp/1.0.0 (ChatGPT)` and `openai-mcp/1.0.0 ( chatgpt; web)` are recognized, and
`openai-mcp/1.0.0 (Codex)`, `openai-mcp/1.0.0 (ChatGPT-Agent)`, and `Mozilla/5.0 openai-mcp/1.0.0
(ChatGPT)` are not.

A value that is not a string of its row's value shape is not a client conversation id. The SDK SHALL derive `$session_id` from `<key> + ":" + <value>`, so ids from two clients
never derive the same session, and SHALL NOT send the value itself in any property. A client
conversation id wins over a conversation handle, because the client sends its id on every call while a
handle groups calls only while the agent copies it into each one: when a call carries both, the SDK
SHALL ignore the handle for `$session_id` and `$mcp_conversation_id`. A call with a client conversation
id SHALL NOT set `$mcp_conversation_id`, which holds only SDK-minted handles.
The SDK SHALL read client conversation ids whether or not conversation anchoring is enabled: reading
one adds nothing the client sees. A handle-free client is a recognized client whose row's Handle is
"none": the SDK leaves `conversation_id` out of its listing (see "Arguments the SDK injects") and mints
it no handle. A row reads "none" only when its client sends an id on every call, and "fallback" when
some versions or kinds of conversation send none, which keep the handle. Being handle-free changes
only what the SDK advertises and mints; a valid handle such a client echoes counts like any other.

#### Scenario: A client conversation id sets the session and adds no conversation_id block
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": "v1/conv-example-0001"}
- **THEN** the result should contain no `conversation_id` text block
- **WHEN** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should be "ses_2f5d35b7108d17c807766f2f769a1e8c"
- **AND** it should have no "$mcp_conversation_id"
- **AND** its "$mcp_session_source" should be "client_metadata"

#### Scenario: A client conversation id wins over a conversation handle
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with arguments `{"query": "flags", "conversation_id": "0190f0e8-7a6b-7c3d-9e4f-5a6b7c8d9e0f"}` and `_meta` {"openai/session": "v1/conv-example-0001"}
- **AND** the SDK is flushed
- **THEN** the tool handler should receive arguments `{"query": "flags"}`
- **AND** the "$mcp_tool_call" event's "$session_id" should be "ses_2f5d35b7108d17c807766f2f769a1e8c"
- **AND** it should have no "$mcp_conversation_id"

#### Scenario: A client conversation id sets the session with conversation anchoring disabled
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": "v1/conv-example-0001"}
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should be "ses_2f5d35b7108d17c807766f2f769a1e8c"

#### Scenario: An invalid client conversation id falls back to a handle
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "codex-mcp-client/0.50.0" calls tool "search_docs" with `_meta` {"sessionId": "not-a-uuid"}
- **THEN** the result's last content block should be a text block of the form `{"conversation_id":"<uuidv7>"}`

#### Scenario: An invalid id from a handle-free client gets no handle
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": ""} twice
- **THEN** neither result should contain a `conversation_id` text block
- **WHEN** the SDK is flushed
- **THEN** the two "$mcp_tool_call" events should have different "$session_id" values

#### Scenario: Codex and VS Code ids set the session
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "codex-mcp-client/0.50.0" calls tool "search_docs" with `_meta` {"sessionId": "019A4F2E-1C3D-7B8A-9E0F-1A2B3C4D5E6F"}
- **AND** an MCP client on protocol revision "2026-07-28" with `_meta` clientInfo name "Visual Studio Code" calls tool "search_docs" with `_meta` {"vscode.conversationId": "3f1c2b7e-8d4a-4c6b-9a1e-5f2d7c8b9a0e"}
- **THEN** neither result should contain a `conversation_id` text block
- **WHEN** the SDK is flushed
- **THEN** the Codex call's "$session_id" should be "ses_0fdf126b8e2c1f9689ca12f3dd3383e6"
- **AND** the VS Code call's "$session_id" should be "ses_0571acb894e6753d33e37e5c2b327c59"

#### Scenario: A key is read only from the client that defines it
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "example-client/1.0" calls tool "search_docs" with `_meta` {"sessionId": "019a4f2e-1c3d-7b8a-9e0f-1a2b3c4d5e6f", "openai/session": "v1/conv-example-0001"}
- **THEN** the result's last content block should be a text block of the form `{"conversation_id":"<uuidv7>"}`
- **WHEN** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should not be "ses_0fdf126b8e2c1f9689ca12f3dd3383e6" or "ses_2f5d35b7108d17c807766f2f769a1e8c"
- **AND** its "$mcp_session_source" should be "conversation"

#### Scenario: A handle-free client's call gets no conversation_id block without its id
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" without `_meta` "openai/session"
- **THEN** the result should contain no `conversation_id` text block

### Requirement: Conversation anchoring

With conversation anchoring enabled, the SDK SHALL accept only UUIDv7-shaped handles (lowercased),
set `$mcp_conversation_id` on the `$mcp_tool_call`, `$mcp_input_required`, `$mcp_unknown_tool`, the reports of "Virtual tools", and any `$exception`, and, for a tool call or
virtual tool call with no client conversation id, no valid handle, and no transport session, from a
client that is not handle-free, mint a UUIDv7 handle and append to the
result's content a text block whose text is the JSON object `{"conversation_id":"<handle>"}`
(whitespace may vary). It MAY also mirror it into `structuredContent` as `{"_mcp_instructions":
{"conversation_id": <handle>}}`, but only for a tool whose advertised output schema is a plain object
without `$ref`, `oneOf`, `anyOf`, or `allOf` at its root that does not already declare
`_mcp_instructions`, on which it declares `_mcp_instructions` as an optional property. A handle that is
not delivered (no result, or a result that cannot carry content, such as `input_required` or a task
handle) SHALL NOT be used for `$session_id` or `$mcp_conversation_id`. A session resolver does not
change anchoring: handles are still advertised, minted, and recorded in `$mcp_conversation_id`, though
they no longer set `$session_id` when the resolver answers. A server that does not want them turns
anchoring off. Anchoring exists because 2026-07-28 has no session: without it every request of a
stateless HTTP client that sends no client conversation id is its own session.

#### Scenario: A conversation handle keeps a stateless client's calls in one session
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client calls tool "search_docs" without a conversation_id argument
- **THEN** the result's last content block should be a text block of the form `{"conversation_id":"<uuidv7>"}`
- **WHEN** the MCP client calls tool "search_docs" again with that conversation_id
- **AND** the SDK is flushed
- **THEN** both "$mcp_tool_call" events should have the same "$session_id"
- **AND** both should have "$mcp_conversation_id" equal to the handle
