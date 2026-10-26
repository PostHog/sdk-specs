## Why

posthog-rs now ships MCP analytics (`posthog_rs::mcp`,
[posthog-rs#308](https://github.com/PostHog/posthog-rs/pull/308)), and the spec does not list it. Checking
it against "Payload privacy" found three rules whose text differs from what posthog-js, posthog-python,
posthog-go, and posthog-rs all send: the binary check, the PostHog token pattern, and object keys. A spec
that every SDK fails in the same way does not tell a new SDK what to build, so each rule needs one answer.

## What Changes

- Applicability lists `posthog-rs | posthog_rs::mcp` (feature `mcp`, rmcp adapter), and "Library
  identity" names `posthog-rs-mcp` with `$lib_version` from `posthog-rs`.
- The binary check accepts `\r` and `\n` in its edge windows and ignores any trailing run of `=`. The
  spec follows the SDKs.
- The PostHog token pattern matches only between ASCII word boundaries. The spec follows the SDKs.
- Object keys in `$mcp_parameters` and `$mcp_response` get the same passes as that property's string
  values. The spec keeps this rule, states it outright, and the SDKs change.
- Scenarios for each of the three rules.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Payload privacy** and **Library identity**, plus the Applicability table.

## Impact

Line-wrapped base64 and tokens are already handled this way by every SDK, so events do not change for
those two rules. Keys that carry a credential or a signed URL stop reaching PostHog once
posthog-js, posthog-python, posthog-go, and posthog-rs redact keys. posthog-js, posthog-python, and
posthog-go also need the binary check read from the edges, and posthog-python needs an ASCII word
boundary; design.md lists each change.
