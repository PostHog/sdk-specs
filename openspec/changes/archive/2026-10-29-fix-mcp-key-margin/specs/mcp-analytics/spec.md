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
  numbers from `$mcp_intent` and every property "Property reference" marks sanitized as free text.

Object keys inside `$mcp_parameters` and `$mcp_response` are captured strings too, because a result
keyed by data (a link check keyed by signed URL) carries the credential in the key. The key list is
matched against each key as received; the key then SHALL get the PostHog token, URL, JSON member, and
binary passes, with the key limit of "Property reference" in place of the string limit. The SHOULD on
other credential-shaped values below does not extend to keys, because entropy detectors read field names
such as `Get_Organization_Memberships` as credentials. When cutting or redaction makes keys of one object
equal, the SDK SHALL keep the entry whose key as received sorts first by Unicode code point.
`$mcp_input_keys` SHALL count a name the PostHog token or URL pass would change as a name that was not
recorded.

These passes SHALL cost in proportion to the property limits, not to the payload. The SDK SHALL first
apply the entry and nesting limits of "Property reference" and the key-based redaction. For each
remaining string with a limit, object keys included, it SHALL run the binary check on the uncut string,
cut the string to its limit plus 1,024 characters, run the remaining passes, then cut it to its limit,
or, when the first cut removed text, also run the same remaining passes on the string's first limit
characters, with no truncation marker, keep the longest common prefix of the two results, compared by
character, and cut that to its limit. The margin lets a match that crosses the limit be recognized
whole. A match split by the cut at the limit can be left raw in the second result, but the first
redacts it, and a match no longer than the margin that is split by the cut at the margin lies past the
end of the second result, so the common prefix holds neither. Measuring by the first result's length
minus the margin instead would also drop kept text for each redaction inside the margin, which empties
a key such as a link whose token alone is longer than the key limit. Scanning the whole payload first
makes one large result cost hundreds of milliseconds.

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
