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
  string of 10,240 or more characters whose first and last 1,024 characters, once any trailing run of
  `=` is set aside, are all base64 or base64url characters, `\r`, or `\n`, because MIME and PEM base64
  break lines; or a `data:` URL whose header ends in `;base64,`;
- redact email addresses, IP addresses, Luhn-valid card numbers, US social security numbers, and phone
  numbers from `$mcp_intent` and every property "Property reference" marks sanitized as free text.

Object keys inside `$mcp_parameters` and `$mcp_response` are captured strings too: each SHALL get every
pass that property's string values get, with the key limit of "Property reference" in place of the
string limit, because a result keyed by data (a link check keyed by signed URL) carries the credential
in the key. The key list is matched against the key as received. When cutting or redaction makes two
keys of one object equal, the SDK SHALL keep exactly one of their entries.

These passes SHALL cost in proportion to the property limits, not to the payload. The SDK SHALL first
apply the entry and nesting limits of "Property reference" and the key-based redaction. For each
remaining string with a limit, object keys included, it SHALL run the binary check on the uncut string,
cut the string to its limit plus 1,024 characters, run the remaining passes, then cut it to its limit,
or, when the first cut removed text, to the passed string's length minus 1,024 if that is smaller. The
margin lets a match that crosses the limit be recognized whole, and the second rule drops the margin's
last 1,024 characters, where a match split by the first cut could otherwise slide under the limit after
an earlier redaction shortens the text. Scanning the whole payload first makes one large result cost
hundreds of milliseconds.

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

#### Scenario: A PostHog token is redacted only as a whole word
- **GIVEN** an MCP server instrumented by the SDK with a tool "save_note"
- **WHEN** an MCP client calls tool "save_note" with arguments `{"note": "key phc_AbCdEfGhIjKlMnOpQrStUvWx for graphs_per_dashboard_and_insight"}`
- **AND** the SDK is flushed
- **THEN** the "$mcp_parameters" should not contain "phc_AbCdEfGhIjKlMnOpQrStUvWx"
- **AND** the "$mcp_parameters" should contain "graphs_per_dashboard_and_insight"

#### Scenario: Line-wrapped base64 in a result is replaced
- **GIVEN** an MCP server instrumented by the SDK with a tool "export" that returns a text block of 12,000 base64 characters broken by `\r\n` every 76 characters and ending in "=="
- **WHEN** an MCP client calls tool "export"
- **AND** the SDK is flushed
- **THEN** the first text block in "$mcp_response" should be "[binary data redacted - not supported by PostHog MCP analytics]"

### Requirement: Library identity

MCP events SHALL carry `$lib` as `posthog-<runtime>-mcp` (such as `posthog-node-mcp`,
`posthog-python-mcp`, `posthog-rs-mcp`) and `$lib_version` as the version of the installed package that
ships the instrumentation (for Python, `posthog`; for Go, `posthog-go`, which builds the events for both
`posthogmcp` and `posthogmcpsdk`; for Rust, `posthog-rs`, which ships `posthog_rs::mcp` behind its
`mcp` feature). `$lib` marks an event as coming from the MCP instrumentation, so the SDK SHOULD NOT
relabel events the host application captures through the same client; where the platform can only
relabel the whole client, the SDK SHALL document that MCP analytics needs a dedicated client.

#### Scenario: Events name the MCP instrumentation
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$lib" should end with "-mcp"
