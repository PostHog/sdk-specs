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

With the error message capture option off (see "Configuration"), `$mcp_error_message` and the
`$exception` value SHALL be `Tool <name> returned an error`, with the call's `$mcp_tool_name`, and the
SDK SHALL NOT send any part of the thrown message or the `isError` content in them. Tool errors often
repeat their arguments, and "Payload privacy" redacts only credentials from them, not
personal data, resource names, identifiers, or configuration values, so this is how a host that turns
parameter and response capture off keeps argument values out of failures too.
`$mcp_is_error`, `$mcp_error_type`, `$mcp_error_expected`, the exception's type, and whether
`$exception` is sent stay the same. `$mcp_response` stays under the response capture option, including the content of an `isError`
result, so a host that wants no failure text turns both off.

The SDK MAY set `$mcp_error_status` to the HTTP status behind a failed call. An SDK that derives it
from a thrown error SHALL derive it this way, so the same failure groups the same in every language:

- Walk the cause chain from the thrown error inward, visiting each error once and at most 50 errors:
  in Python `__cause__`, else `__context__` unless `__suppress_context__` is set (the chain a
  traceback prints); in JavaScript `cause`; elsewhere the platform's standard unwrapping.
- On each error read `status_code`, `statusCode`, and `status`, in that order, first on the error and
  then on its `response`. The first value that is an integer from 100 to 599 is the status; a boolean
  or a numeric string is not one.
- The first error in the chain that yields a status wins, so a status the tool raised itself beats
  one from the error it wrapped. Without one the property is absent, and an `isError` result with no
  thrown error has none. A value the caller sets explicitly wins over a derived one.

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

#### Scenario: With the error message capture option off, a failure is recorded without its text
- **GIVEN** an MCP server instrumented by the SDK with the error message capture option off and a tool "lookup" whose handler throws an error of a custom type named "NotFound" with message "workspace acme-prod not found"
- **WHEN** an MCP client calls tool "lookup"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_is_error" should be the boolean true
- **AND** its property "$mcp_error_type" should name the "NotFound" type
- **AND** its property "$mcp_error_message" should be the string "Tool lookup returned an error"
- **AND** the "$exception" event's exception value should be "Tool lookup returned an error"
- **AND** no sent event should contain "acme-prod"

#### Scenario: A failed call carries the HTTP status of the error it wraps
- **GIVEN** an MCP server instrumented by the SDK, deriving `$mcp_error_status`, with a tool "fetch_invoice" whose handler throws an error with message "invoice lookup failed" caused by an error whose `response` has status 503
- **WHEN** an MCP client calls tool "fetch_invoice"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_error_status" should be the JSON number 503
- **AND** its property "$mcp_error_message" should be "invoice lookup failed"
