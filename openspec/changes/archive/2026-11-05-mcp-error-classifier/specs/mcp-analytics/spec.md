## MODIFIED Requirements

### Requirement: Failure capture

A failed call (an `isError` result or a thrown error) SHALL set `$mcp_is_error: true` and:

- `$mcp_error_type`: a low-cardinality label, never containing the message. An explicit type wins: one
  the caller passes to the manual API, one the error classifier returns, or one the SDK assigns (such as
  `validation` for a framework validation error it recognizes), in that order; explicit types SHOULD
  come from the shared vocabulary `validation`, `permission`, `missing_context`, `not_found`, `timeout`,
  `rate_limited`, `api_4xx`, `api_5xx`, `cancelled`, `input_required`, and `internal`, so failures group
  the same way across servers. An empty or blank type from any source is no type, so the next source
  applies, and an explicit type is sanitized as free text per "Payload privacy" like any other captured
  string. Otherwise it is the thrown error's own type name (in JavaScript, its `name` unless that is the
  generic `"Error"`, then its constructor's name), looking past wrappers the SDK, standard library, or
  MCP framework add; otherwise `"Error"`, which is also the type of an `isError` result without an
  explicit type.
- `$mcp_error_message`: the thrown message or the text of the tool's own `isError` content (never
  the SDK's appended handle), sanitized per "Payload privacy".

The SDK MAY set `$mcp_error_status` to an upstream HTTP status code.

A failure can be expected: an outcome the server returns by design for the agent to act on, such as a
rate limit, a record that does not exist, or arguments the agent must fix. Only the server knows which
failures are expected, so automatic instrumentation SHALL offer the error classifier option (see
"Configuration"): a server callback that receives one value holding the tool name, the `$mcp_error_type`
and `$mcp_error_message` the call would carry without a classifier, and the failure itself when the SDK
holds it. The failure is the tool's own thrown error, looking past the same wrappers as
`$mcp_error_type`, else the `isError` result as the tool produced it, before the SDK appends a
conversation handle. The classifier may return an explicit error type, whether the failure is expected,
both, or nothing. The SDK SHALL call it exactly once for each failed call that ends in a thrown error or
an `isError` result, and for nothing else: never for a failed or cancelled task or an `input_required`
sequence the framework ends, whose types "Tool call event" and "Optional events" fix. The manual API
never calls it: its caller holds the failure and passes the type and the expected flag itself. When the
classifier or the manual API's caller says whether the failure is expected, the SDK SHALL set
`$mcp_error_expected` to that JSON boolean; otherwise it SHALL NOT set it. An expected failure is still
a failed call: it keeps `$mcp_is_error: true` and every other rule of this requirement. A classifier
that fails or returns nothing leaves the call as it would be without one, and SHALL NOT change the
response.

When the SDK emits `$exception`, the event SHALL follow the `exception-event-metadata` capability, with
`$exception_source: "mcp.tool_call"`, `mechanism.handled: true` (the framework turns the failure into a
response to the client), and `mechanism.synthetic: true` for an `isError` result that carried no thrown
error; the exception's type SHALL be the thrown error's own type (`"Error"` for an `isError` result),
never the explicit label, so error tracking groups by real types; and the event SHALL carry
`$exception_level: "error"` and the call's `$session_id` and `$mcp_tool_name`. Failure analytics SHALL
NOT depend on `$exception`, which can be disabled.

#### Scenario: A thrown error is a failed call and still reaches the client
- **GIVEN** an MCP server instrumented by the SDK with a tool "query" whose handler throws an error of a custom type named "UpstreamTimeout" with message "upstream timed out"
- **WHEN** an MCP client calls tool "query"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should name the "UpstreamTimeout" type (platform spelling, such as "UpstreamTimeout" or "errors.UpstreamTimeout")
- **AND** the client should receive the same failure it would receive without instrumentation

#### Scenario: The error classifier labels an isError result as an expected failure
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled, an error classifier that returns error type "not_found" and expected true, and a tool "get_record" that returns a result with isError true and the text "record not found"
- **WHEN** an MCP client calls tool "get_record"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should be "not_found"
- **AND** its property "$mcp_error_expected" should be the boolean true
- **AND** its property "$mcp_error_message" should be "record not found"
- **AND** the client should receive the same result it would receive without instrumentation

#### Scenario: A failed call without a classification has no expected flag
- **GIVEN** an MCP server instrumented by the SDK with no error classifier and a tool "get_record" that returns a result with isError true and the text "record not found"
- **WHEN** an MCP client calls tool "get_record"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event should not have property "$mcp_error_expected"

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
takes the call context and the outcome (the result or the error, an explicit error type and whether the
failure is expected if the caller knows them, and when it ended); it sends the events and returns the
result to deliver, with a minted handle appended. From these inputs the SDK applies every other rule of
this spec itself: the `$mcp_parameters` shape, intent and model, `$session_id`, person and client
identity, failure capture (apart from the error classifier), privacy, and size bounds.

A lower-level method MAY also accept a finished call's fields directly, for a server that already holds
them; it is exempt from producing the same events as automatic instrumentation. It sends
`$mcp_parameters` and `$mcp_response` as the caller passes them, takes whether a failure is expected
next to its explicit error type, and follows the rest of this spec for everything else. A client
conversation id applies only when the caller passes the request's `_meta` together with the `User-Agent`
or client name that recognizes its client. A `$session_id` the caller passes is sent unchanged as the
transport session unless a client conversation id or a conversation handle applies; without any of
these, each call gets a fresh `ses_<UUIDv7>`, as rule 4 of "Session identity" gives a stateless
request, so a server on a one-client connection SHOULD pass its connection's id.

#### Scenario: A manually captured call matches the automatic one
- **GIVEN** an MCP server that dispatches tool "search_docs" itself through the SDK's manual API
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags", "context": "find the flags docs"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's properties "$mcp_tool_name", "$mcp_intent", "$mcp_parameters", and "$mcp_is_error" should equal those automatic instrumentation sends for the same call
- **AND** its property "$session_id" should be a non-empty string

#### Scenario: A manually captured failure can be marked expected
- **GIVEN** an MCP server that records a failed call to tool "query" through the SDK's manual API with error type "rate_limited" and expected true
- **WHEN** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should be "rate_limited"
- **AND** its property "$mcp_error_expected" should be the boolean true
