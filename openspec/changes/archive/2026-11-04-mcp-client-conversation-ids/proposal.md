## Why

MCP clients differ in what they send a server, and the SDK treats them all alike. Some clients name
the conversation themselves: ChatGPT sends `_meta["openai/session"]` on every tool call. Every
client that reaches a server over HTTP names itself in the `User-Agent` of every request. The SDK
uses neither:

- A client that already names the conversation still gets a `conversation_id` argument and a
  `{"conversation_id": "..."}` block in its results. The handle duplicates a grouping key the client
  sends on every call, and starts one call later.
- The SDK cannot leave the argument out of a listing for such a client, because it never looks at
  who is listing.

Two smaller parts of what the SDK adds also describe the data wrongly:

- The virtual tools `get_more_tools` and `send_feedback` declare `readOnlyHint: true`, but each call
  sends an event, which writes data outside the conversation.
- The `context` description asks for 15 to 25 words. A purpose fits in a few words, and longer
  answers pull in the user's own text.

## What Changes

- Add client conversation ids to **Session identity**: a table of known clients, each with the
  `_meta` key that carries its id and the rule that recognizes it from a request (today one row,
  ChatGPT's `openai/session`). The id ranks above the conversation handle. A call with one gets its
  `$session_id` from it and gets no `conversation_id` block.
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
