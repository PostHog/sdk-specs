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

The SDK MAY set `$mcp_error_status` to the HTTP status behind a failed call. An SDK that derives it
from a thrown error SHALL derive it this way, so the same failure groups the same in every language:

- Walk the cause chain from the thrown error inward, visiting each error once: in Python `__cause__`,
  else `__context__` unless `__suppress_context__` is set (the chain a traceback prints); in
  JavaScript `cause`; elsewhere the platform's standard unwrapping.
- On each error read `status_code`, `statusCode`, and `status`, in that order, first on the error and
  then on its `response`. The first value that is an integer from 100 to 599 is the status; a boolean
  or a numeric string is not one.
- The first error in the chain that yields a status wins, so a status the tool raised itself beats
  one from the error it wrapped. Without one the property is absent, and an `isError` result with no
  thrown error has none. A value the caller sets explicitly wins over a derived one.

When it emits `$exception`, the event SHALL follow the `exception-event-metadata` capability, with
`$exception_source: "mcp.tool_call"`, `mechanism.handled: true` (the framework turns the failure into
a response to the client), and `mechanism.synthetic: true` for an `isError` result that carried no thrown error; the
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

#### Scenario: A failed call carries the HTTP status of the error it wraps
- **GIVEN** an MCP server instrumented by the SDK, deriving `$mcp_error_status`, with a tool "fetch_invoice" whose handler throws an error with message "invoice lookup failed" caused by an error whose `response` has status 503
- **WHEN** an MCP client calls tool "fetch_invoice"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_error_status" should be the JSON number 503
- **AND** its property "$mcp_error_message" should be "invoice lookup failed"

