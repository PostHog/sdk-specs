## Why

The spec says the identify option "Resolves `distinct_id`, `$set`, and `$groups` per request" and that
the manual call step takes "the HTTP headers when there are any", but never says which headers a host
callback can read. The SDKs settled that themselves and then had to converge: posthog-ruby copied only
`user-agent`, `x-anthropic-client`, `mcp-session-id` and `mcp-protocol-version` into the callback's
context, so the identify-by-bearer-token pattern the posthog-js and posthog-python docs show resolved
nothing in Ruby and every caller stayed anonymous ([posthog-ruby#320](https://github.com/PostHog/posthog-ruby/pull/320)).
posthog-js (`getRequestHeaders`), posthog-python (`get_request_headers`) and posthog-rs
(`request.http`) all hand over the whole request. An allowlist cannot work here: a server may
authenticate on `Authorization`, `X-Api-Key`, or a tenant header of its own.

The applicability table still lists posthog-ruby as "not yet", though `PostHog::MCP` ships (as
experimental) and is the SDK this change comes from.

## What Changes

- New **Host callback request context** requirement in `mcp-analytics`: the per-request host callbacks
  can read every header, matched case-insensitively; a non-HTTP transport reports no headers rather
  than an empty set; a mutable bag is a per-request copy, so a callback cannot change what
  instrumentation reads afterwards.
- The same requirement holds the capture side still: the SDK captures no header bag, keeps deriving
  only `$mcp_client_user_agent` and `$mcp_vendor_client` from headers, and documentation tells hosts to
  resolve a header to an id or a role rather than return the raw value, which "Payload privacy" only
  redacts when it recognizes it.
- Applicability table: posthog-ruby is `PostHog::MCP` (experimental), not "not yet".

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: new **Host callback request context** requirement; applicability table row for
  posthog-ruby.

## Impact

- **posthog-ruby**: already matches, as of #320.
- **posthog-js**, **posthog-python**, **posthog-rs**: already match; the requirement records what they
  do.
- **posthog-go**: its MCP packages expose the request to the host callbacks; no change expected, but it
  is the one SDK not re-read line by line for this change.
