## Why

A low-level server can create a new instance for each request. A `tools/call` instance might not
have served `tools/list`, so the SDK might not know which arguments it injected. A strict tool can
then reject `context`, `llm_model`, or `conversation_id` before its handler runs.

## What Changes

- Require SDKs to resolve the original tool definition during a call, without a prior listing on
  the same server instance.
- Require a host callback when the framework does not expose a readable tool registry.
- Keep argument ownership three-valued. The SDK strips an argument only when it can prove that it
  owns the argument.
- Add a cross-SDK acceptance scenario for a fresh low-level server with strict validation.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: clarify injected-argument ownership for fresh low-level server instances.

## Impact

This change adds an optional configuration hook for low-level servers. High-level adapters can read
their tool registry and need no new configuration. Existing unresolved low-level calls keep their
fail-open behavior.
