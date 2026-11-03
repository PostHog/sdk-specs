## Overview

posthog-rs ports the redaction passes of `@posthog/core` (`packages/core/src/privacy.ts`) and replays 249
of its outputs as golden cases with no mismatch. Reading the four SDKs against "Payload privacy" found
three rules where the spec says one thing and every SDK does another. For each, the question is which
version sends the right data; the losing side changes.

## Key Decisions

### Binary check: the spec follows the SDKs on newlines and padding

posthog-js, posthog-python, and posthog-go test standard base64 with `^[A-Za-z0-9+/\n\r]+=*$`, and
posthog-rs admits the same characters. All four admit `\r` and `\n` and any run of trailing `=`; the spec
allowed neither. MIME and PEM base64 break lines every 64 or 76 characters, so under the spec's text a
wrapped blob fails the check and is captured as 32,768 characters of text that no reader can decode. A
trailing run of `=` is set aside before the tail window is read, because capping it at two would only let
a blob with more padding through; at least one other character must remain, so a 10,240-character rule
of `=` stays text.

The cost: newline-separated alphanumeric text of 10,240 or more characters, such as about 250 commit
hashes one per line, is replaced too. Every SDK already replaces it, since each line is base64. The edge
windows widen this to such text with other characters in its middle.

The two alphabets stay separate, as posthog-js and posthog-go have them: either every edge character is
base64 or a newline, or every edge character is base64url. posthog-rs accepts the union, which replaces a
long list of UUIDs or snake_case names one per line (hex, `-`, `_`, and `\n`) that no base64 encoder
produces.

The edge windows stay. posthog-js, posthog-python, and posthog-go run the test on the whole string, which
costs time in proportion to the payload and breaks the rule that these passes cost in proportion to the
property limits. posthog-js and posthog-go also require a base64url string to contain `-` or `_`, stop
its padding at two, and test the whole payload of a `data:` URL. posthog-python has neither a base64url
branch nor a `data:` URL branch, so it sends both as text. posthog-rs reads the edges and only the header
of a `data:` URL, as the spec says.

### PostHog token pattern: the spec follows the SDKs

Every SDK matches `\bph[a-z]_[A-Za-z0-9_-]{20,}\b`. The spec had no boundary, which redacts snake_case
names whose words end in `ph` and a letter: `graphs_per_dashboard_and_insight` contains
`phs_per_dashboard_and_insight`, 29 characters of the pattern. Those names are argument and field names,
the data that says what a tool was asked and returned.

The boundary does miss tokens that follow a word character. A token glued to a word (`my_phc_...`), after
a JSON `\n` escape in a text copy (`\nphc_...`), or after a percent escape (`%3Dphc_...`) is not
matched. posthog-python's entropy fallback catches the glued word but rejects words containing `"`, so
the escaped forms are sent. This is the cost of keeping names whole. The trailing boundary only stops a
match before trailing `-`, which carries no part of the key.

The boundary is ASCII: only ASCII letters, digits, and `_` are word characters. posthog-js, posthog-go
(RE2), and posthog-rs (`(?-u:\b)`) already do this. posthog-python compiles the pattern without
`re.ASCII`, so a token next to a non-ASCII letter (`éphc_...`, `phc_...é`) has no boundary and is sent
unredacted.

### Object keys: the spec keeps redacting them, and the SDKs change

All four SDKs test each object key against the key list, and only posthog-rs cuts keys to the 256
characters "Property reference" sets; posthog-js, posthog-python, and posthog-go send keys whole. None runs
the token or URL passes on a key. The spec's first sentence, "Captured strings SHALL NOT carry the
credentials and personal data the rules below recognize", covers keys, and the cost paragraph treats every
string with a limit alike. A result keyed by data carries the credential in the key, such as a link check
that returns `{"https://bucket.test/a.png?X-Amz-Signature=...": 200}`. The JSON text copy of the same
result is redacted today, so `$mcp_response` shows the signature in its structured copy and hides it in
its text copy.

The spec now says it outright and names the passes: PostHog token, URL, JSON member, and binary. The
SHOULD on other credential-shaped values does not reach keys. posthog-python, posthog-go, and posthog-rs
implement it with an entropy detector that reads field names such as `Get_Organization_Memberships` as
secrets, and posthog-rs and posthog-python already keep names out of it for that reason.

Redacting or cutting keys can make two keys of one object equal, and one of their values is then lost: a
link check whose two signed URLs differ only in the signature keeps one status. The SDK keeps the entry
whose key as received sorts first by code point, so every SDK sends the same event; posthog-go already
sorts keys when it walks an object. Keeping the signature is the alternative, and it is the leak this rule
exists to stop.

`$mcp_input_keys` records undeclared top-level names when input key recording allows it. Such a name is
the same string as a `$mcp_parameters` key, so a name the token or URL pass would change is counted as not
recorded, which the property already marks with its `"[redacted]"` entry.

## SDK changes

- posthog-js (`packages/core/src/privacy.ts`, `packages/mcp/src/extensions/truncation.ts`): run the
  token, URL, JSON member, and binary passes on object keys and cut keys to 256 characters, keeping the
  first key by code point on a collision; read the binary check from the edge windows, and only the header
  of a `data:` URL; apply the passes to recorded `$mcp_input_keys` names.
- posthog-python (`posthog/mcp/_sanitization.py`, `posthog/mcp/_truncation.py`): the same key passes,
  key cut, and collision rule; read the binary check from the edge windows and add the base64url alphabet
  and the `data:` header test; compile the token pattern with `re.ASCII`; apply the passes to recorded
  `$mcp_input_keys` names.
- posthog-go (`posthogmcp/sanitize.go`, `posthogmcp/truncate.go`): the same key passes, key cut, and
  collision rule; read the binary check from the edge windows, and only the header of a `data:` URL; apply
  the passes to recorded `$mcp_input_keys` names.
- posthog-rs (`src/mcp/bounds/payload.rs`, `src/mcp/privacy/binary.rs`): run the key passes in
  `bound_object` with the collision rule; test each alphabet on its own instead of their union, and
  require a character other than `=`.

## Alternatives Considered

- **Exempt keys, as the SDKs do.** Rejected because a map keyed by signed URLs sends the signature, while
  the same map's JSON text copy is redacted.
- **Replace a key that contains a credential with `[redacted]` whole.** Rejected because every key that
  merely contains a signed URL would collapse into one entry, although the rest of each key is data.
- **Keep the token pattern unbounded.** Rejected because it redacts ordinary snake_case names to catch
  only tokens glued to a word or an escape.
- **Check the whole string for base64, as three SDKs do.** Rejected because its cost grows with the
  payload.
- **Require fixed-length lines inside the edge windows.** Not taken here: hash lists also have fixed-length
  lines, so it would not keep them as text.

## Open Questions

None. Of the new scenarios, the whole-word token one passes in every SDK today and is added to
`acceptance/public/mcp-analytics.feature`. The object-key scenario joins that feature once the SDK
changes above ship, and the line-wrapped base64 one once the adapters can build its 157-line result.
