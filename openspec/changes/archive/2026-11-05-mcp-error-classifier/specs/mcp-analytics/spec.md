## MODIFIED Requirements

### Requirement: Failure capture

A failed call (an `isError` result or a thrown error) SHALL set `$mcp_is_error: true` and:

- `$mcp_error_type`: a low-cardinality label, never containing the message. An explicit type wins: one
  the caller passes to the manual API, one the error classifier returns, or one the SDK assigns (such
  as `validation` for a framework validation error it recognizes), in that order; explicit types
  SHOULD come from the shared vocabulary `validation`, `permission`, `missing_context`, `not_found`,
  `timeout`, `rate_limited`, `api_4xx`, `api_5xx`, `cancelled`, `input_required`, and `internal`, so
  failures group the same way across servers. Otherwise it is the thrown error's own type name (in
  JavaScript, its `name` unless that is the generic `"Error"`, then its constructor's name), looking
  past wrappers the SDK, standard library, or MCP framework add; otherwise `"Error"`, which is also the
  type of an `isError` result without an explicit type.
- `$mcp_error_message`: the thrown message or the text of the tool's own `isError` content (never
  the SDK's appended handle), sanitized per "Payload privacy".

The SDK MAY set `$mcp_error_status` to an upstream HTTP status code.

A failure can be expected: an outcome the server returns by design for the agent to act on, such as a
rate limit, a record that does not exist, or arguments the agent must fix. Only the server knows which
failures are expected, so the SDK SHALL offer the error classifier option (see "Configuration") on
automatic instrumentation: a server callback that receives the tool name and the failure, and may
return an explicit error type, whether the failure is expected, both, or nothing. The failure is the
thrown value when the SDK has one, else the `isError` result as the tool produced it, before the SDK
appends a conversation handle. The SDK SHALL call it once for each failed tool call that reaches a
final outcome, and for nothing else. When the classifier, or the caller of the manual API, says whether
the failure is expected, the SDK SHALL set `$mcp_error_expected` to that JSON boolean; otherwise it
SHALL NOT set it. A value the caller passes to the manual API wins over the classifier's. An expected
failure is still a failed call: it keeps `$mcp_is_error: true` and every other rule of this
requirement. A classifier that fails or returns nothing leaves the call as it would be without one, and
SHALL NOT change the response.

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
- **GIVEN** an MCP server instrumented by the SDK with an error classifier that returns error type "not_found" and expected true, and a tool "get_record" that returns a result with isError true and the text "record not found"
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
identity, failure capture (including the error classifier, for what the caller leaves unset), privacy,
and size bounds.

A lower-level method MAY also accept a finished call's fields directly, for a server that already holds
them; it is exempt from producing the same events as automatic instrumentation. It sends
`$mcp_parameters` and `$mcp_response` as the caller passes them, takes whether a failure is expected
next to its explicit error type, and follows the rest of this spec for everything else. A `$session_id`
the caller passes is sent unchanged as the transport session unless a conversation handle applies;
without either, each call gets a fresh `ses_<UUIDv7>`, as rule 3 of "Session identity" gives a
stateless request, so a server on a one-client connection SHOULD pass its connection's id.

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
