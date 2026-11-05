## Why

Some tools fail on purpose. A rate limit, a record that does not exist, or arguments the agent must fix
are outcomes the server returns by design, and the agent is meant to act on them. Today the data cannot
tell them apart from failures the server owner has to fix. An `isError` result from automatic
instrumentation always has `$mcp_error_type: "Error"`, because the spec gives automatic instrumentation
no way to receive an explicit type. One production server reported 148,967 calls in 30 days, with
2,872 failures, all typed `"Error"`. By the owner's own classification, 81% of those failures were
expected (PostHog/posthog#113659).

## What Changes

- Add an error classifier option to the Configuration table. It is a server callback that, for a failed
  tool call, may return an explicit error type and whether the failure is expected.
- Add `$mcp_error_expected`, a JSON boolean on failed calls, to the Property reference.
- Modify **Failure capture**. Automatic instrumentation takes an explicit type from the classifier.
  An expected failure is still a failed call: `$mcp_is_error` stays `true`, and `$exception` is
  unchanged. Add `not_found` to the shared type vocabulary.
- Modify **Manual capture**. The result step and the lower-level method take whether the failure is
  expected, next to the explicit error type.
- Add scenarios for a classified `isError` result and a manually captured expected failure.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Failure capture** and **Manual capture** requirements, the Configuration
  table, and the Property reference.

## Impact

Nothing changes for a host that sets no classifier and passes no expected flag. A host that sets one
gets explicit types on failures automatic instrumentation captures, and `$mcp_error_expected` on the
failures it marks. Every SDK that implements MCP analytics adds the option and the manual field.
