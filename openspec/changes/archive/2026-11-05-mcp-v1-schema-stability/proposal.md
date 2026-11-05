## Why

The SDKs are heading to a stable release: `@posthog/mcp` 1.0, and a stability promise for `posthog.mcp`. A stable release promises that saved insights keep working, so the spec has to say what stays fixed. It says nothing about stability today.

Two rules also need to be pinned down before that promise.

- **Unregistered tools.** "Tool call event" says a call to a tool the server never registered is not a `$mcp_tool_call`, for every SDK. The only scenario that checks it is tagged `@mcp_unknown_tool_capable`, so SDKs that don't emit `$mcp_unknown_tool` never run it. posthog-js, posthog-python, and posthog-ruby count those calls as failed `$mcp_tool_call`s today. Fixing that after a stable release would move tool-call counts and error rates in existing insights.
- **`llm_model`.** The spec requires `llm_model` wherever the SDK strips it before validation. The answers given to OpenAI's plugin review say it is optional, and that a model the client sends in `_meta` is used instead. A required argument pushes an agent that doesn't know its model to guess one.

## What Changes

- **New requirement "Event schema stability".** A release doesn't rename or remove an event or property, change its type, or change which requests emit an event. It may add events, properties, and enumerated values. Captured string values may change when redaction or size bounds cut more. A breaking change to the spec adds a new name and keeps the old one.
- **Tool call event.** New untagged scenario: a call to `no_such_tool` sends no `$mcp_tool_call`. The requirement text doesn't change.
- **Arguments the SDK injects.** `llm_model` is optional everywhere. `context` keeps its current rule.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: new **Event schema stability** requirement. **Tool call event** and **Arguments the SDK injects** change.

## Impact

- posthog-js, posthog-python, and posthog-ruby fail the new unknown-tool scenario until they stop counting unregistered tools as calls. posthog-go and posthog-rs already pass it.
- Every SDK that marks `llm_model` required changes its listing to optional. No event changes.
- The stability requirement adds no work. It records the promise that a stable release makes.
