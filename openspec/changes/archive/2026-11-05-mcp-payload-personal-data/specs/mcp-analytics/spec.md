## MODIFIED Requirements

### Requirement: Payload privacy

Captured strings SHALL NOT carry the credentials and personal data the rules below recognize. Each
redaction replaces what it matched with `[redacted]`, unless a rule names another placeholder. Before
sending, the SDK SHALL:

- redact the value of every key that, case-insensitively and as a whole,
  is one of: authorization, cookie, set-cookie, x-api-key, token, password, secret, or api key, api
  token, access token, refresh token, client secret, private key written with `-`, `_`, or no
  separator;
- redact PostHog tokens (`ph` plus a lowercase letter and `_`, then 20 or more of `[A-Za-z0-9_-]`,
  between word boundaries, where only ASCII letters, digits, and `_` are word characters, so a name
  such as `graphs_per_dashboard_and_insight` is kept), URL user info, and URL query and fragment
  fields named by that key list or as a signature (such as `sig`, `signature`, `X-Amz-Signature`);
- redact, inside any string, the value of a JSON member whose key is on that key list, writing
  `"[redacted]"` so JSON stays valid (`"password": "hunter2"` becomes `"password": "[redacted]"`),
  because a tool that returns `structuredContent` also returns it as JSON text. The value is a string,
  number, boolean, or flat array of those; a string may be cut off at a line end or the text's end,
  even after a trailing `\`. Values that nest objects, and JSON inside a JSON string, are out of scope;
- replace with the placeholder `[binary data redacted - not supported by PostHog MCP analytics]` a
  string of 10,240 or more characters that is a `data:` URL whose header ends in `;base64,`, or that,
  once any trailing run of `=` is set aside, is not empty and has first and last 1,024 characters all
  from one alphabet: base64 with `\r` and `\n`, because MIME and PEM base64 break lines, or base64url;
- redact email addresses, IP addresses, Luhn-valid card numbers, US social security numbers, and phone
  numbers from `$mcp_intent` and every property "Property reference" marks sanitized as free text;
- unless the payload personal data option is off, apply the payload personal data pass to:
  - every string value and object key at any depth of `$mcp_parameters` and `$mcp_response`, text
    blocks and their JSON text copies included;
  - every number in them whose digits form a Luhn-valid card number, replaced by the string
    `"[redacted]"`, which JSON text writes with its quotes so it stays valid JSON;
  - `$mcp_error_message`, and `$mcp_resource_name` on a resource read, where it holds the URI;
  - each exception's `value` in the `$exception` sibling, and the stack-frame source lines it sends
    (such as `pre_context`, `context_line`, and `post_context`), each first cut to 2,048 characters.

  Other numbers and booleans are kept. The pass matches text as captured, so an address written as
  `%40` or `\u0040` is not recognized.

  The payload personal data pass is the personal data pass above, narrowed because payloads carry
  identifiers that only look like personal data. It redacts email addresses, Luhn-valid card numbers,
  US social security numbers, and IPv6 addresses as that pass does. It redacts an IPv4 address only
  when the address is not loopback (`127.0.0.0/8`), private (`10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`), link-local (`169.254.0.0/16`), or `0.0.0.0`, and does not directly follow a
  letter, digit, `.`, `:`, or `@`, so `node:22.11.0.3` and `pkg@1.2.3.4` are kept. It redacts a phone
  number only when it starts with `+` and a country code or has its area code in parentheses, so
  `415-555-0142` is kept and `+1 415 555 0142` and `(415) 555-0142` are not.

Object keys inside `$mcp_parameters` and `$mcp_response` are captured strings too, because a result
keyed by data (a link check keyed by signed URL) carries the credential in the key. The key list is
matched against each key as received; the key then SHALL get the PostHog token, URL, JSON member, and
binary passes, with the key limit of "Property reference" in place of the string limit. The SHOULD on
other credential-shaped values below does not extend to keys, because entropy detectors read field names
such as `Get_Organization_Memberships` as credentials. When cutting or redaction makes keys of one object
equal, the SDK SHALL keep the entry whose key as received sorts first by Unicode code point.
`$mcp_input_keys` SHALL count a name the PostHog token, URL, or payload personal data pass would
change as a name that was not recorded.

These passes SHALL cost in proportion to the property limits, not to the payload. The SDK SHALL first
apply the entry and nesting limits of "Property reference" and the key-based redaction. For each
remaining string with a limit, object keys included, it SHALL run the binary check on the uncut string,
cut the string to its limit plus 1,024 characters, run the remaining passes, then cut it to its limit,
or, when the first cut removed text, also run the same remaining passes on the string's first limit
characters, with no truncation marker, keep the longest common prefix of the two results, compared by
Unicode code point, and cut that to its limit. The margin lets a match that crosses the limit be
recognized whole. A match split by the cut at the limit can be left raw in the second result, but the
first redacts it, and a match no longer than the margin that is split by the cut at the margin lies past
the end of the second result, so the common prefix holds neither. Scanning the whole payload first makes
one large result cost hundreds of milliseconds.

The personal data pass on payloads is one of the remaining passes of the cut above, so it costs in
proportion to the property limits too, and a match that crosses a string's limit is redacted whole. It
runs before the URL pass, because that pass percent-encodes `@` and would hide an address in a query.
Turning the option off changes only payloads, error text, and exception values: intent and free-text
properties keep the pass, and the credential passes still apply everywhere.

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

#### Scenario: A credential in an object key is redacted
- **GIVEN** an MCP server instrumented by the SDK with a tool "check_links"
- **WHEN** an MCP client calls tool "check_links" with arguments `{"links": {"https://bucket.test/a.png?X-Amz-Signature=abc123": "logo"}}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should not contain "abc123"
- **AND** the "$mcp_parameters" should contain "logo"

#### Scenario: A long signed link used as an object key keeps its start
- **GIVEN** an MCP server instrumented by the SDK with a tool "check_links"
- **WHEN** an MCP client calls tool "check_links" with arguments `{"links": {"<link>": "report"}}`, where `<link>` is "https://acme.s3.amazonaws.com/q3.pdf?token=" followed by 1,300 "A" characters, then "&X-Amz-Signature=abc123"
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should contain "https://acme.s3.amazonaws.com/q3.pdf"
- **AND** the "$mcp_parameters" should not contain "AAAAAAAAAAAAAAAAAAAA"
- **AND** the "$mcp_parameters" should contain "report"

#### Scenario: A PostHog token is redacted only as a whole word
- **GIVEN** an MCP server instrumented by the SDK with a tool "save_note"
- **WHEN** an MCP client calls tool "save_note" with arguments `{"note": "key phc_AbCdEfGhIjKlMnOpQrStUvWx for graphs_per_dashboard_and_insight"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should not contain "phc_AbCdEfGhIjKlMnOpQrStUvWx"
- **AND** the "$mcp_parameters" should contain "graphs_per_dashboard_and_insight"

#### Scenario: Line-wrapped base64 in a result is replaced
- **GIVEN** an MCP server instrumented by the SDK with a tool "export" that returns a text block of 157 lines of 76 base64 characters joined by `\r\n`, the last line ending in "=="
- **WHEN** an MCP client calls tool "export"
- **AND** the SDK is flushed
- **THEN** the first text block in "$mcp_response" should be "[binary data redacted - not supported by PostHog MCP analytics]"

#### Scenario: Personal data in arguments and results is redacted by default
- **GIVEN** an MCP server instrumented by the SDK with a tool "lookup_customer" that returns the text "Customer ada@example.com last seen from 203.0.113.7"
- **WHEN** an MCP client calls tool "lookup_customer" with arguments `{"email": "ada@example.com", "limit": 5}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should not contain "ada@example.com"
- **AND** the "$mcp_parameters" arguments should have key "email" and "limit" equal to the number 5
- **AND** the "$mcp_response" should not contain "ada@example.com"
- **AND** the "$mcp_response" should not contain "203.0.113.7"

#### Scenario: A personal key and a card number in a result are redacted and its JSON stays valid
- **GIVEN** an MCP server instrumented by the SDK with a tool "list_accounts" that returns `structuredContent` `{"accounts":{"ada@example.com":{"plan":"pro"}},"card":4111111111111111,"count":3}` and the same JSON as a text block
- **WHEN** an MCP client calls tool "list_accounts"
- **AND** the SDK is flushed
- **THEN** the "$mcp_response" should not contain "ada@example.com"
- **AND** the "$mcp_response" should not contain "4111111111111111"
- **AND** the first text block in "$mcp_response" should parse as JSON with "count" equal to 3

#### Scenario: Identifiers that only look like personal data are kept in payloads
- **GIVEN** an MCP server instrumented by the SDK with a tool "deploy_status" that returns the text "Order 415-555-0142 built with node:22.11.0.3, db at 127.0.0.1:5432, support +1 415 555 0142"
- **WHEN** an MCP client calls tool "deploy_status"
- **AND** the SDK is flushed
- **THEN** the "$mcp_response" should contain "Order 415-555-0142"
- **AND** the "$mcp_response" should contain "node:22.11.0.3"
- **AND** the "$mcp_response" should contain "127.0.0.1:5432"
- **AND** the "$mcp_response" should not contain "+1 415 555 0142"

#### Scenario: Personal data in error text and exceptions is redacted by default
- **GIVEN** an MCP server instrumented by the SDK with a tool "lookup_customer" that fails with message "No account for ada@example.com"
- **WHEN** an MCP client calls tool "lookup_customer"
- **AND** the SDK is flushed
- **THEN** the "$mcp_error_message" should not contain "ada@example.com"
- **AND** the "$exception" event should not contain "ada@example.com"

#### Scenario: Turning the option off keeps personal data in payloads but not in intent
- **GIVEN** an MCP server instrumented by the SDK with the payload personal data option off and a tool "lookup_customer" that returns the text "Customer ada@example.com"
- **WHEN** an MCP client calls tool "lookup_customer" with arguments `{"email": "ada@example.com", "context": "look up ada@example.com"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should contain "ada@example.com"
- **AND** the "$mcp_response" should contain "ada@example.com"
- **AND** the "$mcp_intent" should not contain "ada@example.com"

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
- `$mcp_missing_capability` from the SDK's `get_more_tools` virtual tool and `$mcp_feedback` from its
  `send_feedback` virtual tool (names configurable). `get_more_tools` declares a required `context`
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
- `$mcp_initialize` for a legacy `initialize`, unless the host turns the initialize event option
  off (see "Configuration"). With the option off, the SDK SHALL NOT send `$mcp_initialize`, and SHALL
  change nothing else: the session token, `$session_id`, and the client and server identity of later
  events stay the same. The SDK SHALL NOT send an `$exception` for a failed `initialize`, with the
  option on or off.
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

#### Scenario: With the tools list event option off, a listing sends no $mcp_tools_list and keeps injected arguments (@mcp_tools_list_capable)
- **GIVEN** an MCP server instrumented by the SDK with the tools list event option off and a tool "search_docs"
- **WHEN** an MCP client lists tools
- **AND** calls tool "search_docs" with arguments `{"query": "flags", "context": "find flag docs"}`
- **AND** the SDK is flushed
- **THEN** no "$mcp_tools_list" event should be sent
- **AND** the listed "search_docs" input schema should include `context`
- **AND** the "$mcp_tool_call" event's property "$mcp_intent" should be "find flag docs"
