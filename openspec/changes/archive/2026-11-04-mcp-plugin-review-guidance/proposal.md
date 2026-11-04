## Why

The SDK adds data to every tool a server advertises and to some of its results. Three parts of it send
more than the data needs, or describe it wrongly:

- A client that already names the conversation in `_meta` still gets a `conversation_id` argument
  and a `{"conversation_id": "..."}` block in its results. The handle duplicates a grouping key the
  client sends on every call, and starts one call later.
- The virtual tools `get_more_tools` and `send_feedback` declare `readOnlyHint: true`, but each call
  sends an event, which writes data outside the conversation.
- The `context` description asks for 15 to 25 words. A purpose fits in a few words, and longer
  answers pull in the user's own text.

OpenAI's plugin review team gave guidance on all three. design.md records it.

## What Changes

- Add client conversation ids to **Session identity**: a table of known `_meta` keys (today only
  ChatGPT's `openai/session`), ranked above the conversation handle. A call with one gets its
  `$session_id` from it and gets no `conversation_id` block. It wins over a handle.
- **Manual capture**: the list step takes the listing request's headers, and the lower-level method
  lets a client conversation id override a passed `$session_id`.
- **Arguments the SDK injects**: leave `conversation_id` out of a listing requested by a recognized
  client, and ask for a few words of purpose in `context`, with no quoted user text.
- Add **Virtual tool annotations**: `readOnlyHint`, `destructiveHint`, `idempotentHint`, and
  `openWorldHint`, all false.
- Add acceptance scenarios for each.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Session identity**, **Arguments the SDK injects**, **Manual capture**, a
  new **Virtual tool annotations** requirement, the Terminology list, the Configuration table, and the
  Property reference.

## Impact

For a ChatGPT conversation, `$session_id` now comes from ChatGPT's own id, so one conversation is one
session from its first call. Before, a conversation grouped by handle split off its first call, and a
transport session could span several conversations. No event carries
`$mcp_conversation_id` for those calls. Every other client sees no change apart from the `context`
description and the virtual tools' annotations. `llm_model` is unchanged. The JavaScript, Python, Go,
Ruby, and Rust SDKs implement this in separate PRs.
