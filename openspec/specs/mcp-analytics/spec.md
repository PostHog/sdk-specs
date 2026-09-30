# MCP Analytics Specification

## Purpose

MCP analytics gives the owner of an MCP server what they need to make it succeed with the agents that
use it: which tools agents call, why, what the tools return, how long each call takes, and how it
fails, including the successful calls that return the wrong thing. An add-on package wraps a server in
one call and sends these as `$mcp_*` events through the host SDK's `capture`. It covers data collection
only: what each SDK sends and what it means. The required properties and their types are fixed, so
events from every SDK mean the same thing. Where this spec leaves a choice open, choose what helps the
server owner find out why their server does or does not serve agents well.

It covers MCP revisions up to 2026-07-28, legacy stateful connections and stateless HTTP requests
alike. It does not cover LLM analytics (tokens, cost, prompts), which belong to `$ai_*` events.

## Applicability

`server`. An add-on package rather than a core client method.

| SDK | Package |
|-----|---------|
| posthog-js | `@posthog/mcp` |
| posthog-python | `posthog.mcp` (inside `posthog`) |
| posthog-go | `posthogmcp` (manual API), `posthogmcpsdk` (go-sdk adapter) |
| posthog-ruby | not yet |

## Public signatures

Every SDK offers automatic instrumentation that wraps a server in one call, following platform idiom
(such as `instrument(server, client)` or `posthogmcpsdk.Instrument(server, posthogmcp.New(client))`),
and the manual API of "Manual capture" for servers it cannot wrap. What each SDK ships today is
documented in its README.

## Terminology

- **Legacy**: MCP revisions up to 2025-11-25, with an `initialize` handshake and, on Streamable HTTP,
  an optional `Mcp-Session-Id`.
- **Stateless HTTP request**: an HTTP request that carries no session id: every 2026-07-28 HTTP
  request, and a legacy one without `Mcp-Session-Id`. It carries its protocol version in `_meta` or the
  `MCP-Protocol-Version` header (a legacy `initialize` carries it in its params) and, on 2026-07-28,
  usually its client info in `_meta`.
- **Transport session**: what the transport already uses to keep one client's requests together. There
  are two kinds, and only these:
  - an id carried on every request: a legacy `Mcp-Session-Id`, an HTTP+SSE session, a framework session
    id that stays the same across a client's requests, or a replayed PostHog session token;
  - a one-client connection, which needs no id because it can only ever carry one client. On stdio the
    client launches the server as a child process and talks to it over stdin and stdout, so each
    process serves exactly one client. An in-memory connection (client and server wired together in
    one program) and a WebSocket work the same way.

  Credentials, cookies, and client addresses are never transport sessions. A long-lived HTTP server
  without session ids has none: one process there serves every client.
- **Conversation handle**: a UUIDv7 the SDK returns to the agent and the agent echoes as the
  `conversation_id` argument, the only grouping a stateless HTTP request can carry.
- **Final outcome**: the result or error that ends a tool call, as opposed to an `input_required`
  round or a task handle.

## Configuration

Every option of a feature the SDK implements is configurable; names follow platform convention. This
table is the one place defaults are stated.

| Option | Default | Effect |
|--------|---------|--------|
| context (intent) | on | Injects the `context` argument and captures `$mcp_intent`; description configurable |
| model capture | on | Reads the model from request metadata, or injects an `llm_model` argument for the agent to self-report |
| intent fallback | none | Server callback that supplies intent when the agent does not (`$mcp_intent_source: "inferred"`) |
| conversation anchoring | on | Injects `conversation_id`, mints handles, and derives `$session_id` from them |
| identify | none | Resolves `distinct_id`, `$set`, and `$groups` per request |
| exception autocapture | on | Emits `$exception` next to failed calls |
| parameter capture | on | Sends `$mcp_parameters` |
| response capture | on | Sends `$mcp_response` on `$mcp_tool_call`, including successful calls, where a wrong or empty result is the failure no error flag shows |
| before-send hook | none | Modifies or drops each MCP event before capture |
| missing-capability tool | off | Adds a virtual tool that emits `$mcp_missing_capability` |
| feedback tool | off | Adds a virtual tool that emits `$mcp_feedback`; the host may declare extra report arguments and a handler for reports |
| server build | none | Sends `$mcp_server_build` |
| input key recording | declared names only | Which argument names `$mcp_input_keys` records |
| input aliases | none | Per tool, the other names the server accepts for an argument, for `$mcp_input_keys` and `$mcp_input_aliases_used` |

## Property reference

Every property this spec constrains, with its type and limit; SDKs MAY send other `$mcp_*` properties.
Requirements say when each is set; this table is the one place types and limits are stated. "Known"
means set whenever the SDK can determine the value. Events: "call" is `$mcp_tool_call`, "report" is
`$mcp_missing_capability` and `$mcp_feedback`.

| Property | Events | Type and limit | Presence |
|----------|--------|----------------|----------|
| `$mcp_tool_name` | call, `$exception`, `$mcp_input_required`, `$mcp_unknown_tool` | non-empty string, at most 256 characters; sanitized as free text unless it is known to be a registered tool's name | required |
| `$mcp_is_error` | call | JSON boolean | required |
| `$mcp_duration_ms` | call, `$mcp_input_required` | JSON number, milliseconds | required |
| `$mcp_source` | call | `"posthog_mcp_analytics"` | required |
| `$session_id` | all | non-empty string | required |
| `$mcp_resource_name` | call, report | string, the tool name (on a report, the virtual tool's), at most 256 characters | should |
| `$mcp_tool_description`, `$mcp_tool_category` | call | string, at most 2,048 characters | known |
| `$mcp_llm_model` | call, report | string, at most 256 characters | known |
| `$mcp_llm_model_source` | call, report | `"client_metadata"` or `"self_reported"` | with `$mcp_llm_model` |
| `$mcp_intent` | call, report | non-empty string, at most 2,048 characters | known |
| `$mcp_intent_source` | call, report | `"context_parameter"`, `"inferred"`, or `"client_metadata"` | with `$mcp_intent` |
| `$mcp_conversation_id` | call, report, `$exception`, `$mcp_input_required`, `$mcp_unknown_tool` | lowercase UUIDv7 | known |
| `$mcp_error_type` | failed call | string, low cardinality, at most 256 characters | failed calls |
| `$mcp_error_message` | failed call | string, at most 2,048 characters | failed calls |
| `$mcp_error_status` | failed call | JSON number, an HTTP status code | may |
| `$mcp_server_build` | all | string, 1 to 256 characters, an immutable build id (a commit SHA or image digest); rejected at configuration when out of range, never truncated or shrunk | may |
| `$mcp_input_keys` | call | array of at most 20 entries: recorded top-level argument names, declared ones (the schema's and accepted aliases) sorted, then others sorted, then one `"[redacted]"` entry if room remains and a name was not recorded or exceeded 64 characters; injected names the tool does not declare are excluded | may |
| `$mcp_input_aliases_used` | call | array of at most 20 sorted `"<alias>:<canonical>"` strings, each name at most 64 characters, one for each argument the agent sent only under an alias, naming the first alias present in the server's order | may |
| `$mcp_feedback_<name>` | `$mcp_feedback` | a host-declared report argument's value: a string sanitized as free text, at most 2,048 characters; a number or boolean as is; other JSON as JSON text within that limit; a value that does not match the declared type or enum is not sent | per field |
| `$mcp_parameters`, `$mcp_response` | call, listings | JSON; string values at most 32,768 characters, keys at most 256, arrays and objects at most 100 entries, nesting at most 10 levels | per Configuration |
| `$mcp_session_id` | any | equal to `$session_id` | may |
| `$mcp_client_name`, `$mcp_client_version`, `$mcp_protocol_version`, `$mcp_server_name`, `$mcp_server_version`, `$mcp_client_user_agent`, `$mcp_vendor_client` | all | string, at most 256 characters | known |
| `$mcp_listed_tool_names` | `$mcp_tools_list` | JSON array of strings | required on that event |
| `$mcp_input_request_methods` | `$mcp_input_required` | JSON array of the `method` of each `inputRequests` value, sorted by key, duplicates kept, at most 100 entries; `[]` when the round has only `requestState` | required on that event |
| `$mcp_feedback_summary`, `_details`, `_friction_points`, `_suggested_improvement` | `$mcp_feedback` | string, sanitized as free text, at most 2,048 characters | per field |
| `$mcp_feedback_type` | `$mcp_feedback` | `"missing_capability"`, `"issue"`, `"praise"`, or `"other"` (an unknown value becomes `"other"`) | required on that event |
| `$mcp_feedback_sentiment` | `$mcp_feedback` | `"positive"`, `"neutral"`, `"negative"`, or `"mixed"` | per field |
| `$mcp_feedback_task_completed` | `$mcp_feedback` | JSON boolean | per field |
| `$mcp_feedback_tool` | `$mcp_feedback` | string, sanitized as free text, at most 256 characters | per field |

Length limits count characters, keep the start of the string, include any truncation marker, and apply
before the byte bound of "Event size bounds".

## Requirements

### Requirement: Observer-only instrumentation

An SDK SHALL let a server be instrumented with one call taking the MCP server and a configured PostHog
client. Instrumentation SHALL NOT change what the server returns, apart from the injected arguments of
"Arguments the SDK injects", the conversation handle and session token of "Session identity", and the
virtual tools of "Optional events". A failure inside instrumentation (an exception, a panic, a
serialization error, an unreachable PostHog endpoint) SHALL NOT change the response or reach the tool
handler or the MCP client.

Instrumentation SHALL NOT add avoidable latency to the response: sanitizing, truncating, and
serializing an event SHOULD happen after the response is handed to the transport, and sending SHALL use
the host SDK's asynchronous capture. State kept per session (identity, advertised schemas, pending
tasks) SHALL be bounded by count, for example a least-recently-used cache, so a long-lived server with
many conversations does not grow without limit. On a server that lives for a single request, the SDK
SHALL let the host flush without delaying the response (for example through the platform's wait-until
hook).

#### Scenario: A tool result reaches the client unchanged
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled and a tool "search_docs" that returns the text "Found 3 results"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **THEN** the client should receive a result whose content is exactly one text block "Found 3 results"
- **AND** the result should not be marked as an error

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

### Requirement: Failure capture

A failed call (an `isError` result or a thrown error) SHALL set `$mcp_is_error: true` and:

- `$mcp_error_type`: a low-cardinality label, never containing the message. An explicit type wins: one
  the caller passes to the manual API, or one the SDK assigns (such as `validation` for a framework
  validation error it recognizes); automatic instrumentation has no other way to receive one; explicit
  types SHOULD come from the shared vocabulary `validation`, `permission`, `missing_context`,
  `timeout`, `rate_limited`, `api_4xx`, `api_5xx`, `cancelled`, `input_required`, and `internal`, so
  failures group the same way across servers. Otherwise it is the thrown error's own type name (in
  JavaScript, its `name` unless that is the generic `"Error"`, then its constructor's name), looking
  past wrappers the SDK, standard library, or MCP framework add; otherwise `"Error"`, which is also the
  type of an `isError` result without an explicit type.
- `$mcp_error_message`: the thrown message or the text of the tool's own `isError` content (never
  the SDK's appended handle), sanitized per "Payload privacy".

The SDK MAY set `$mcp_error_status` to an upstream HTTP status code. When it emits `$exception`, the
event SHALL follow the `exception-event-metadata` capability, with `$exception_source:
"mcp.tool_call"`, `mechanism.handled: true` (the framework turns the failure into a response to the
client), and `mechanism.synthetic: true` for an `isError` result that carried no thrown error; the
exception's type SHALL be the thrown error's own type (`"Error"` for an `isError` result), never the
explicit label, so error tracking groups by real types; and the event SHALL carry `$exception_level:
"error"` and the call's `$session_id` and `$mcp_tool_name`. Failure analytics SHALL NOT depend on
`$exception`, which can be disabled.

#### Scenario: A thrown error is a failed call and still reaches the client
- **GIVEN** an MCP server instrumented by the SDK with a tool "query" whose handler throws an error of a custom type named "UpstreamTimeout" with message "upstream timed out"
- **WHEN** an MCP client calls tool "query"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should name the "UpstreamTimeout" type (platform spelling, such as "UpstreamTimeout" or "errors.UpstreamTimeout")
- **AND** the client should receive the same failure it would receive without instrumentation

### Requirement: Session identity

Every MCP event SHALL carry a non-empty `$session_id` that groups one agent conversation as far as the
transport allows, and never groups requests from different clients. It comes from whoever groups the
client's calls, first match wins:

1. The agent: a conversation handle (see below), echoed by the agent or minted for this call and
   delivered in its result.
2. The transport: a transport session.
   - An id: a legacy `Mcp-Session-Id` that decodes as a PostHog session token gives its `sid` unchanged;
     any other id is derived as below. An id the framework assigns afresh to every request is not a
     transport session.
   - A one-client connection: the SDK generates a `ses_<UUIDv7>` when the connection opens (for stdio,
     when the process starts) and uses it for every request on that connection. A new connection gets a
     new one, and so does the first tool call that arrives 30 minutes or more after the previous tool
     call on that connection ended, because a desktop app can keep one stdio process alive across many
     separate chats. Every event of a call uses the id resolved when the call arrived.
3. Nobody: a stateless HTTP request carrying neither gets a fresh `ses_<UUIDv7>` of its own.

A derived `$session_id` is `"ses_" + H(x) + H(x + "::salt")`. `H` runs two 32-bit FNV-1a lanes over the
input's characters (ASCII, so bytes, UTF-16 units, and code points agree), seeds `0x84222325` and
`0xcbf29ce4`, primes `0x1b3` and `0x193`, each step `lane = (lane XOR c) * prime mod 2^32`, and returns
the two lanes as 8 lowercase hex digits each. Derivation is deterministic so replicas, restarts, and
SDKs in different languages agree.

Conversation anchoring exists because 2026-07-28 has no session: without it every request of a
stateless HTTP client is its own session. When enabled, the SDK SHALL accept only UUIDv7-shaped handles
(lowercased), set `$mcp_conversation_id` on the `$mcp_tool_call`, `$mcp_input_required`,
`$mcp_unknown_tool`, the reports of "Optional events", and any `$exception`, and, for a tool call or
virtual tool call with no valid handle and no transport session, mint a UUIDv7 handle and append to the
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

#### Scenario: Session ids derive identically across SDKs
- **GIVEN** a conversation handle "0190f0e8-7a6b-7c3d-9e4f-5a6b7c8d9e0f"
- **WHEN** the SDK derives a session id from it
- **THEN** the result should be "ses_6df45f0102a182bcd5e8dd5dad6c65a0"

### Requirement: Person identity

The event `distinct_id` SHALL be the identity the server resolves for the request, else `$session_id`.
Without a resolved identity every event, `$exception` included, SHALL set `$process_person_profile:
false`, so anonymous calls create no person profiles. With one, the SDK SHALL NOT set it, and SHALL
send identity properties as `$set` and groups as `$groups`. The SDK MAY also send `$identify`, at most
once per session in each process and again when the identity changes; it SHALL carry only the
identity (`distinct_id`, `$set`, `$groups`, `$session_id`) and client and server identity, never
`$mcp_parameters` or `$mcp_response`. Nothing depends on it, because every event carries the identity.

#### Scenario: An anonymous call does not create a person
- **GIVEN** an MCP server instrumented by the SDK with no identify option
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should equal its "$session_id"
- **AND** its property "$process_person_profile" should be the boolean false

### Requirement: Client and server identity

Every MCP event SHALL carry, when known, `$mcp_client_name`, `$mcp_client_version`,
`$mcp_protocol_version` (the revision string, such as `"2026-07-28"`), `$mcp_server_name`, and
`$mcp_server_version`. Per-request sources SHALL win: `_meta` `io.modelcontextprotocol/clientInfo` and
`io.modelcontextprotocol/protocolVersion`, then the `MCP-Protocol-Version` header, then a replayed
session token's `cn`, `cv`, and `pv`. The `initialize` handshake is the fallback only when it is bound
to the request's transport session (a session-scoped instance, or a one-client connection); a handshake
on an instance that serves several clients, or one the framework synthesized without the request's own
`_meta`, does not identify the request's client, which is then unidentified. A handshake the framework
builds from the request's own `_meta` counts as a per-request source. On HTTP the SDK SHALL also set
`$mcp_client_user_agent` from `User-Agent` and `$mcp_vendor_client` from `X-Anthropic-Client`.
`$mcp_vendor_client`, `$mcp_client_user_agent`, and `$mcp_client_name` together identify the calling
client; a request with none of them has an unidentified client.

#### Scenario: A 2026-07-28 request identifies its client from _meta
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client on protocol revision "2026-07-28" calls tool "search_docs" with `_meta` clientInfo name "claude-code" version "2.1.0"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_client_name" should be "claude-code"
- **AND** its property "$mcp_client_version" should be "2.1.0"
- **AND** its property "$mcp_protocol_version" should be the string "2026-07-28"

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

### Requirement: Payload capture

Automatic instrumentation SHALL capture `$mcp_parameters` as
`{"request": {"method": "tools/call", "params": {"name": <tool>, "arguments": <arguments>}}}`
(`arguments` is `{}` when absent). `params` SHALL hold only `name` and `arguments`: an MRTR retry's
`inputResponses` and `requestState` carry the user's answers and server state, and are never captured.
The response capture option governs `$mcp_response` on `$mcp_tool_call`. In `$mcp_response`, `image`
and `audio` blocks and `resource` blocks with a `blob` SHALL be replaced by text placeholders.

#### Scenario: Automatic instrumentation captures arguments in the request shape
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find docs"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_parameters" should include `{"request": {"method": "tools/call", "params": {"name": "search_docs", "arguments": {"query": "flags"}}}}`

### Requirement: Manual capture

An SDK SHALL offer a manual API for servers it cannot instrument automatically, such as a custom
dispatcher, a gateway, or a framework without an adapter. Given the same traffic, its step-based path
SHALL produce the same `$mcp_tool_call` and `$exception` events as automatic instrumentation; for the
events of "Optional events" it MAY offer capture methods. It SHALL work in three steps. A list step
takes the server's tools and returns them with the injected arguments advertised. A call step takes the
tool's registered definition (input schema, description, `_meta`) when the tool exists, the arguments
as the agent sent them, the request's `_meta`, the HTTP headers when there are any, the transport
session when there is one, whether the tool exists (known to exist, known not to, or unknown for a
server with no registry), and the time the request started; it returns the arguments for the handler
and a call context, and for a tool known not to exist it emits `$mcp_unknown_tool` where the SDK does.
The transport session is either a raw id, derived per rule 2 of "Session identity", or a key the caller
keeps for the lifetime of a one-client connection, which the SDK tracks and rotates. A result step
takes the call context and the outcome (the result or the error, an explicit error type if any, and
when it ended); it sends the events and returns the result to deliver, with a minted handle appended.
From these inputs the SDK applies every other rule of this spec itself: the `$mcp_parameters` shape,
intent and model, `$session_id`, person and client identity, failure capture, privacy, and size bounds.

A lower-level method MAY also accept a finished call's fields directly, for a server that already holds
them; it is exempt from producing the same events as automatic instrumentation. It sends
`$mcp_parameters` and `$mcp_response` as the caller passes them and follows the rest of this spec for
everything else. A `$session_id` the caller passes is sent unchanged as the transport session unless a
conversation handle applies; without either, each call gets a fresh `ses_<UUIDv7>`, as rule 3 of
"Session identity" gives a stateless request, so a server on a one-client connection SHOULD pass its
connection's id.

#### Scenario: A manually captured call matches the automatic one
- **GIVEN** an MCP server that dispatches tool "search_docs" itself through the SDK's manual API
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find the flags docs"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's properties "$mcp_tool_name", "$mcp_intent", "$mcp_parameters", and "$mcp_is_error" should equal those automatic instrumentation sends for the same call
- **AND** its property "$session_id" should be a non-empty string

### Requirement: Payload privacy

Captured strings SHALL NOT carry the credentials and personal data the rules below recognize. Each
redaction replaces what it matched with `[redacted]`, unless a rule names another placeholder. Before
sending, the SDK SHALL:

- redact the value of every key that, case-insensitively and as a whole,
  is one of: authorization, cookie, set-cookie, x-api-key, token, password, secret, or api key, api
  token, access token, refresh token, client secret, private key written with `-`, `_`, or no
  separator;
- redact PostHog tokens (`ph` plus a lowercase letter and `_`, then 20 or more of `[A-Za-z0-9_-]`),
  URL user info, and URL query and fragment fields named by that key list or as a signature (such as
  `sig`, `signature`, `X-Amz-Signature`);
- redact, inside any string, the value of a JSON member whose key is on that key list, writing
  `"[redacted]"` so JSON stays valid (`"password": "hunter2"` becomes `"password": "[redacted]"`),
  because a tool that returns `structuredContent` also returns it as JSON text. The value is a string,
  number, boolean, or flat array of those; a string may be cut off at a line end or the text's end,
  even after a trailing `\`. Values that nest objects, and JSON inside a JSON string, are out of scope;
- replace with the placeholder `[binary data redacted - not supported by PostHog MCP analytics]` a
  string of 10,240 or more characters whose first and last 1,024 characters are all base64 or base64url
  characters (`=` padding allowed at the end), or that is a `data:` URL whose header ends in
  `;base64,`;
- redact email addresses, IP addresses, Luhn-valid card numbers, US social security numbers, and phone
  numbers from `$mcp_intent` and every property "Property reference" marks sanitized as free text.

These passes SHALL cost in proportion to the property limits, not to the payload. The SDK SHALL first
apply the entry, nesting, and key limits of "Property reference" and the key-based redaction. For each
remaining string with a limit it SHALL run the binary check on the uncut string, cut the string to its
limit plus 1,024 characters, run the remaining passes, then cut it to its limit, or, when the first cut
removed text, to the passed string's length minus 1,024 if that is smaller. The margin lets a match
that crosses the limit be recognized whole, and the second rule drops the margin's last 1,024
characters, where a match split by the first cut could otherwise slide under the limit after an earlier
redaction shortens the text. Scanning the whole payload first makes one large result cost hundreds of
milliseconds.

The SDK SHOULD also redact other credential-shaped values (known key formats, long high-entropy
tokens). It SHALL expose a before-send hook that can modify or drop each MCP event after this
requirement and "Event size bounds" apply, whose output is exempt from both, following the
`before-send-hook` capability (a hook that throws drops the event); dropping a `$mcp_tool_call` also
drops its `$exception`.

#### Scenario: Credentials in arguments and error text are redacted
- **GIVEN** an MCP server instrumented by the SDK with a tool "fetch_page" that fails with message "GET https://svc:hunter2@internal.test/doc?token=abc failed"
- **WHEN** an MCP client calls tool "fetch_page" with arguments `{"url": "https://example.com", "api_key": "sk-live-123"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" arguments should have "api_key" equal to "[redacted]"
- **AND** the "$mcp_error_message" should not contain "hunter2"
- **AND** the "$mcp_error_message" should not contain "token=abc"

#### Scenario: A credential in a result's JSON text copy is redacted
- **GIVEN** an MCP server instrumented by the SDK with a tool "get_user" that returns `structuredContent` `{"user":"ada","password":"hunter2"}` and the text block `{"user":"ada","password":"hunter2"}`
- **WHEN** an MCP client calls tool "get_user"
- **AND** the SDK is flushed
- **THEN** the first text block in "$mcp_response" should be `{"user":"ada","password":"[redacted]"}`
- **AND** the "$mcp_response" should not contain "hunter2"

### Requirement: Event size bounds

Every MCP event's properties, `$set` and `$groups` included, SHALL serialize to at most 102,400 bytes
of compact UTF-8 JSON, without ever dropping the event or a required property of "Tool call event". The
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

### Requirement: Library identity

MCP events SHALL carry `$lib` as `posthog-<runtime>-mcp` (such as `posthog-node-mcp`,
`posthog-python-mcp`) and `$lib_version` as the version of the installed package that ships the
instrumentation (for Python, `posthog`; for Go, `posthog-go`, which builds the events for both
`posthogmcp` and `posthogmcpsdk`). `$lib` marks an event as coming from the MCP instrumentation, so the
SDK SHOULD NOT relabel events the host application captures through the same client; where the platform
can only relabel the whole client, the SDK SHALL document that MCP analytics needs a dedicated client.

#### Scenario: Events name the MCP instrumentation
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$lib" should end with "-mcp"

### Requirement: Optional events

Every event below SHALL carry the properties of "Client and server identity" and "Session identity",
and SHALL come only from a request the client sent: never from a request the framework dispatches
internally, and never `$mcp_initialize` without an `initialize`. Automatic instrumentation SHOULD emit
`$mcp_input_required` and `$mcp_unknown_tool`, and MAY emit the others; a manual API MAY offer capture
methods for any of them. An SDK declares which of these events it emits as the acceptance capability
tags `@mcp_input_required_capable`, `@mcp_unknown_tool_capable`, and `@mcp_tools_list_capable`, and
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
- `$mcp_initialize` for a legacy `initialize`; `$mcp_resource_read` and `$mcp_resources_list` for
  resource requests. `$mcp_resource_read` SHALL NOT carry the resource's contents.

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
