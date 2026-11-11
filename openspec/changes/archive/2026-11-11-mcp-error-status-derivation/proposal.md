## Why

The MCP failure views group failed calls by `$mcp_error_status`, but only PostHog's own MCP server sets
it. The spec allows it as a `MAY` and says nothing about where the value comes from, so an SDK that
wanted to fill it had to invent a rule, and two SDKs could put different numbers on the same failure.
Every failure from an external server lands in the "unknown" bucket today. Rootly, a large MCP
Analytics customer, asked for it in PostHog/posthog-python#1223: their tools raise an HTTP client
error, and the status is right there on its `response`.

## What Changes

- **Failure capture**: `$mcp_error_status` stays a `MAY`. An SDK that derives it from a thrown error
  SHALL walk the cause chain from the thrown error inward, at most 50 errors, and take the first integer from 100 to 599
  found in `status_code`, `statusCode`, or `status`, on the error or its `response`. A caller's
  explicit value wins. One new scenario.
- Property reference: the row says the value is an integer from 100 to 599 (prose alignment, applied
  at archive).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Failure capture** and the Property reference.

## Impact

No SDK has to change. posthog-python (`posthog.mcp`) and posthog-js (`@posthog/mcp`) implement the
derivation; posthog-go, posthog-ruby and posthog-rs can follow. PostHog's own server already reads
`status` from its API error, found through the `cause` chain, so its values match the rule.
