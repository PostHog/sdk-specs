## Overview

posthog-rs ports the redaction passes of `@posthog/core` (`packages/core/src/privacy.ts`) and replays 249
of its outputs as golden cases with no mismatch. Reading the four SDKs against "Payload privacy" found
three rules where the spec says one thing and every SDK does another. For each, the question is which
version sends the right data; the losing side changes.

## Key Decisions

### Binary check: the spec follows the SDKs on characters and padding

Every SDK's base64 test admits `\r` and `\n` (`^[A-Za-z0-9+/\n\r]+=*$` in posthog-js, posthog-python, and
posthog-go; the same character set in posthog-rs) and any run of trailing `=`. The spec allowed neither.
MIME and PEM base64 break lines every 64 or 76 characters, so under the spec's text a wrapped blob
fails the check and is captured as 32,768 characters of text that no reader can use. Any run of
trailing `=` is ignored before the tail window is read: a run of `=` is not text, and capping it at two
would only let a blob with padding inside its last window through.

The edge windows stay. posthog-js, posthog-python, and posthog-go run the test on the whole string,
which costs time in proportion to the payload and breaks the requirement that these passes cost in
proportion to the property limits. They also require a base64url string to contain `-` or `_` and stop
its padding at two, and posthog-js and posthog-go test the whole payload of a `data:` URL. posthog-rs
reads only the first and last 1,024 characters of the string without its trailing `=`, over the union of
both alphabets, and reads only the header of a `data:` URL, which is what the spec says.

### PostHog token pattern: the spec follows the SDKs

Every SDK matches `\bph[a-z]_[A-Za-z0-9_-]{20,}\b`. The spec had no boundary, which redacts snake_case
names whose words end in `ph` and a letter: `graphs_per_dashboard_and_insight` contains
`phs_per_dashboard_and_insight`, 29 characters of the pattern. Those names are argument and field
names, the data that says what a tool was asked and returned. A token captured in text sits after a
quote, `=`, `:`, `/`, or whitespace, all non-word characters, so the leading boundary does not hide one.
A token glued to a preceding word character (`my_phc_...`) is not redacted by this pattern; that case is
left to the SHOULD on other credential-shaped values. The trailing boundary only stops a match before
trailing `-`, which carries no part of the key.

The boundary is ASCII: only ASCII letters, digits, and `_` are word characters. posthog-js, posthog-go
(RE2), and posthog-rs (`(?-u:\b)`) already do this. posthog-python compiles the pattern without
`re.ASCII`, so a token next to a non-ASCII letter (`éphc_...`, `phc_...é`) has no boundary and is sent
unredacted.

### Object keys: the spec keeps redacting them, and the SDKs change

All four SDKs test each object key against the key list and cut it to 256 characters, but never run the
token or URL passes on it. The spec's first sentence, "Captured strings SHALL NOT carry the credentials
and personal data the rules below recognize", covers keys, and the cost paragraph treats every string
with a limit alike. A result keyed by data carries the credential in the key: a link check that returns
`{"https://bucket.test/a.png?X-Amz-Signature=...": 200}`, or a map from API key to its owner. The JSON
text copy of the same result is redacted today, so the event shows the value in one property and hides it
in the other.

The spec now says it outright: keys get the passes the property's string values get, under the key
limit. Redacting a key can make two keys of one object equal, as cutting two long keys at 256 characters
already can. The SDK keeps one of their entries; which one is left open, because posthog-go's maps have
no order to pick by, and both entries describe the same redacted name.

## SDK changes

- posthog-js (`packages/core/src/privacy.ts`): run the token and URL passes on object keys in
  `sanitizeValueWith`; read the binary check from the edge windows over both alphabets, and only the
  header of a `data:` URL.
- posthog-python (`posthog/mcp/_sanitization.py`): run the passes on keys in `_sanitize_value_with`;
  read the binary check from the edge windows; compile the token pattern with `re.ASCII`.
- posthog-go (`posthogmcp/sanitize.go`): run the passes on keys in `sanitizeValue`; read the binary
  check from the edge windows, and only the header of a `data:` URL.
- posthog-rs (`src/mcp/bounds/payload.rs`): run the passes on keys in `bound_object`.

## Alternatives Considered

- **Exempt keys, as the SDKs do.** Rejected because a map keyed by signed URLs or tokens would send the
  credential, while the same map's JSON text copy is redacted.
- **Replace a key that contains a credential with `[redacted]` whole.** Rejected because every such key
  in one object would collapse to one entry, and the rest of each key is data.
- **Keep the token pattern unbounded.** Rejected because it redacts ordinary snake_case names to catch
  only tokens glued to a word.
- **Check the whole string for base64, as three SDKs do.** Rejected because its cost grows with the
  payload.

## Open Questions

None. Acceptance scenarios for these rules stay in the spec until the SDKs above ship, so that adding them
does not fail SDK suites that run the public feature.
