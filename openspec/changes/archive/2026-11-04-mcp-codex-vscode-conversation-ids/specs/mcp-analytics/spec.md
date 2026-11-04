## MODIFIED Requirements

### Requirement: Session identity

Every MCP event SHALL carry a non-empty `$session_id` that groups one agent conversation as far as the
transport allows, and never groups requests from different clients. It comes from whoever groups the
client's calls, first match wins:

1. The client: a client conversation id (see below) in the tool call's `_meta`.
2. The agent: a conversation handle (see below), echoed by the agent or minted for this call and
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
SDKs in different languages agree.

A client conversation id is a value an MCP client puts in a `tools/call` request's `_meta` to name the
conversation the call belongs to. This table lists every key the SDK reads. A request comes from a
recognized client when it matches a row's recognition rule, and the SDK SHALL read a row's key only
from a request that rule recognizes, so an unprefixed key such as `sessionId` is read only from the
client that defines it:

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
conversation id wins over a conversation handle: when a call carries both, the SDK SHALL ignore the
handle for `$session_id` and `$mcp_conversation_id`. The client's id names the conversation from its
first call, while a handle starts at the second call and holds only while the agent copies it. A call
with a client conversation id SHALL NOT set `$mcp_conversation_id`, which holds only SDK-minted handles.
The SDK SHALL read client conversation ids whether or not conversation anchoring is enabled: reading
one adds nothing the client sees. A handle-free client is a recognized client whose row's Handle is
"none": the SDK leaves `conversation_id` out of its listing (see "Arguments the SDK injects") and mints
it no handle. A row reads "none" only when its client sends an id on every call, and "fallback" when
some versions or kinds of conversation send none, which keep the handle. Being handle-free changes
only what the SDK advertises and mints; a valid handle such a client echoes counts like any other.

Conversation anchoring exists because 2026-07-28 has no session: without it every request of a
stateless HTTP client that sends no client conversation id is its own session. When enabled, the SDK SHALL accept only UUIDv7-shaped handles
(lowercased), set `$mcp_conversation_id` on the `$mcp_tool_call`, `$mcp_input_required`,
`$mcp_unknown_tool`, the reports of "Optional events", and any `$exception`, and, for a tool call or
virtual tool call with no client conversation id, no valid handle, and no transport session, from a
client that is not handle-free, mint a UUIDv7 handle and append to the
result's content a text block whose text is the JSON object `{"conversation_id":"<handle>"}`
(whitespace may vary). It MAY also mirror it into `structuredContent` as `{"_mcp_instructions":
{"conversation_id": <handle>}}`, but only for a tool whose advertised output schema is a plain object
without `$ref`, `oneOf`, `anyOf`, or `allOf` at its root that does not already declare
`_mcp_instructions`, on which it declares `_mcp_instructions` as an optional property. A handle that is
not delivered (no result, or a result that cannot carry content, such as `input_required` or a task
handle) SHALL NOT be used for `$session_id` or `$mcp_conversation_id`.

A legacy stateless HTTP server handles each request on a fresh instance, so the SDK MAY carry the
client's session in the `Mcp-Session-Id` of the `initialize` response, which the client replays: a
PostHog session token, the unpadded base64url of the compact JSON object
`{"sid":<session id>,"cn":<client name>,"cv":<client version>,"pv":<protocol revision>}`, where only
`sid` is required. It SHALL NOT mint a token for a 2026-07-28 request or when the request or transport
already carries a session, and SHALL return it only in that response, never store it on transport state
other clients share. A token is at most 4,096 characters, and base64 padding is accepted when decoding;
a value that does not decode to an object whose `sid` is a non-empty string of at most 128 characters
is not a token.

#### Scenario: A conversation handle keeps a stateless client's calls in one session
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client calls tool "search_docs" without a conversation_id argument
- **THEN** the result's last content block should be a text block of the form `{"conversation_id":"<uuidv7>"}`
- **WHEN** the MCP client calls tool "search_docs" again with that conversation_id
- **AND** the SDK is flushed
- **THEN** both "$mcp_tool_call" events should have the same "$session_id"
- **AND** both should have "$mcp_conversation_id" equal to the handle

#### Scenario: A client conversation id sets the session and adds no conversation_id block
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": "v1/conv-example-0001"}
- **THEN** the result should contain no `conversation_id` text block
- **WHEN** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should be "ses_2f5d35b7108d17c807766f2f769a1e8c"
- **AND** it should have no "$mcp_conversation_id"

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
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" with `_meta` {"openai/session": ""}
- **THEN** the result should contain no `conversation_id` text block
- **WHEN** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's "$session_id" should not be "ses_2f5d35b7108d17c807766f2f769a1e8c"

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

#### Scenario: A handle-free client's call gets no conversation_id block without its id
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring enabled, on a transport that carries no session
- **WHEN** an MCP client with `User-Agent` "openai-mcp/1.0.0 (ChatGPT)" calls tool "search_docs" without `_meta` "openai/session"
- **THEN** the result should contain no `conversation_id` text block

#### Scenario: Session ids derive identically across SDKs
- **GIVEN** a conversation handle "0190f0e8-7a6b-7c3d-9e4f-5a6b7c8d9e0f"
- **WHEN** the SDK derives a session id from it
- **THEN** the result should be "ses_6df45f0102a182bcd5e8dd5dad6c65a0"

### Requirement: Arguments the SDK injects

The SDK SHALL advertise each of these arguments that is enabled on every tool in `tools/list`, leaving
the registered tool unchanged: `context` (the agent's reason for the call), `llm_model` (the agent's
model), and `conversation_id`. The SDK SHALL:

- leave `conversation_id`, and the `_mcp_instructions` output-schema declaration of "Session
  identity", out of a listing requested by a handle-free client of "Session identity". That client
  names the conversation in `_meta`, so the argument would only add a second, weaker grouping key;

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

### Requirement: Manual capture

An SDK SHALL offer a manual API for servers it cannot instrument automatically, such as a custom
dispatcher, a gateway, or a framework without an adapter. Given the same traffic, its step-based path
SHALL produce the same `$mcp_tool_call` and `$exception` events as automatic instrumentation; for the
events of "Optional events" it MAY offer capture methods. It SHALL work in three steps. A list step
takes the server's tools and the listing request's HTTP headers when there are any, and returns them with the injected arguments advertised. A call step takes the
tool's registered definition (input schema, description, `_meta`) when the tool exists, the arguments
as the agent sent them, the request's `_meta`, the HTTP headers when there are any, the transport
session when there is one, the client's `initialize` `clientInfo` when the caller holds one bound to
the request's transport session, whether the tool exists (known to exist, known not to, or unknown for a
server with no registry), and the time the request started; it returns the arguments for the handler
and a call context, and for a tool known not to exist it emits `$mcp_unknown_tool` where the SDK does.
The transport session is either a raw id, derived per rule 3 of "Session identity", or a key the caller
keeps for the lifetime of a one-client connection, which the SDK tracks and rotates. A result step
takes the call context and the outcome (the result or the error, an explicit error type if any, and
when it ended); it sends the events and returns the result to deliver, with a minted handle appended.
From these inputs the SDK applies every other rule of this spec itself: the `$mcp_parameters` shape,
intent and model, `$session_id`, person and client identity, failure capture, privacy, and size bounds.

A lower-level method MAY also accept a finished call's fields directly, for a server that already holds
them; it is exempt from producing the same events as automatic instrumentation. It sends
`$mcp_parameters` and `$mcp_response` as the caller passes them and follows the rest of this spec for
everything else. A client conversation id applies only when the caller passes the request's `_meta`
together with the `User-Agent` or client name that recognizes its client. A `$session_id` the caller
passes is sent unchanged as the transport session unless a client conversation id or a conversation
handle applies; without any of these, each call gets a fresh
`ses_<UUIDv7>`, as rule 4 of
"Session identity" gives a stateless request, so a server on a one-client connection SHOULD pass its
connection's id.

#### Scenario: A manually captured call matches the automatic one
- **GIVEN** an MCP server that dispatches tool "search_docs" itself through the SDK's manual API
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find the flags docs"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's properties "$mcp_tool_name", "$mcp_intent", "$mcp_parameters", and "$mcp_is_error" should equal those automatic instrumentation sends for the same call
- **AND** its property "$session_id" should be a non-empty string
