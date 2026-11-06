## MODIFIED Requirements

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

With the error message capture option off (see "Configuration"), `$mcp_error_message` and the
`$exception` value SHALL be `Tool <name> returned an error`, with the call's `$mcp_tool_name`, and the
SDK SHALL NOT send any part of the thrown message or the `isError` content in them. Tool errors often
repeat their arguments, and "Payload privacy" redacts only credentials from them, so this is how a
host that turns parameter and response capture off keeps argument values out of failures too.
`$mcp_is_error`, `$mcp_error_type`, the exception's type, and whether `$exception` is sent stay the
same. `$mcp_response` stays under the response capture option, including the content of an `isError`
result, so a host that wants no failure text turns both off.

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

#### Scenario: With the error message capture option off, a failure is recorded without its text
- **GIVEN** an MCP server instrumented by the SDK with the error message capture option off and a tool "lookup" whose handler throws an error of a custom type named "NotFound" with message "workspace acme-prod not found"
- **WHEN** an MCP client calls tool "lookup"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should name the "NotFound" type
- **AND** its property "$mcp_error_message" should be the string "Tool lookup returned an error"
- **AND** the "$exception" event's exception value should be "Tool lookup returned an error"
- **AND** no sent event should contain "acme-prod"
