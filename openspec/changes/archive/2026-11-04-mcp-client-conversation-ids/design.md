## Context

The SDK groups tool calls into conversations with signals the client happens to send. Clients differ
in what they send, so the design starts from what each one gives a server.

| Client | Conversation id in `tools/call` `_meta` | `User-Agent` over HTTP | `clientInfo.name` | Evidence |
|---|---|---|---|---|
| ChatGPT | `openai/session`, a string documented as an anonymized conversation id; lifetime and format not stated | `openai-mcp/<version> (ChatGPT)` | unknown | docs; observed |
| OpenAI Codex | `threadId` and `sessionId`, both UUIDv7, unprefixed keys | `codex-mcp-client/<version>` from the CLI; `openai-mcp/<version> (Codex)` also observed | `codex-mcp-client` | source; observed |
| VS Code (Copilot agent mode) | `vscode.conversationId`: the chat session id for local chats, a resource URI otherwise | `Visual Studio Code/<version>` | the product's long name | source |
| Claude.ai and Claude Desktop | none found | `Claude-User` | `claude-ai` | user reports |
| Claude Code | none; `claudecode/toolUseId` names the call, not the conversation | `claude-code/<version> (...)` | unknown | user reports; observed |
| Cursor | none found | `cursor/<version> ...` | unknown | user reports; observed |
| Gemini CLI | none; only `progressToken` | none set in its source | `gemini-cli-mcp-client` | source |

"Observed" means the string appears among the User-Agents PostHog's MCP analytics already classifies.
Those also include `openai-mcp/<version> (Agent Builder)` and `openai-mcp/<version> (Responses API)`:
several OpenAI surfaces share the `openai-mcp` token and differ in the parenthetical.
Sources:

- ChatGPT: the [Apps SDK reference](https://developers.openai.com/apps-sdk/reference), section
  "`_meta` fields the client provides". The same table lists `openai/locale`, `openai/userAgent`,
  `openai/userLocation`, and `openai/subject`, and says `openai/userAgent` is a best-effort hint, not a
  way to detect the calling surface.
- Codex: `codex-rs/core/src/mcp_tool_call.rs` (`with_mcp_tool_call_ids_meta`) and
  `codex-rs/rmcp-client/src/utils.rs` (`MCP_USER_AGENT`), and `codex-rs/protocol/src/thread_id.rs` and
  `session_id.rs` (`Uuid::now_v7`) in
  [openai/codex](https://github.com/openai/codex).
- VS Code: `src/vs/workbench/contrib/mcp/common/mcpServer.ts` (`vscode.conversationId`),
  `mcpServerRequestHandler.ts` in the same folder (`clientInfo`), and
  `src/vs/workbench/api/common/extHostMcp.ts` (`user-agent`, `${product.nameLong}/${product.version}`) in
  [microsoft/vscode](https://github.com/microsoft/vscode).
- Gemini CLI: `packages/core/src/tools/mcp-client.ts` in
  [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli).
- Claude: [anthropics/claude-code#41836](https://github.com/anthropics/claude-code/issues/41836),
  where users captured the headers and `_meta` that Claude.ai and Claude Code send.

Three facts follow for the SDK:

1. Some clients name the conversation on every call. Their id does not depend on the agent copying
   anything, which the SDK's own handle does. The handle is the fallback
   for clients that send no id.
2. Each client uses its own key, and some keys are unprefixed (Codex's `sessionId`). Reading an id needs a
   per-client table, not a guess at key names.
3. HTTP clients that name themselves do so in the `User-Agent`, on every request. It is the one
   signal present at `tools/list` on every protocol revision, which is where the SDK decides what to
   advertise. Not every client sets one (Gemini CLI does not), so it can recognize a client but never
   rule one out.

## Goals / Non-Goals

**Goals:** a rule for client conversation ids that any client joins by adding a table row; no handle,
argument, or result block for a client that sends one; accurate annotations on the virtual tools; a
shorter `context` request.

**Non-goals:**

- Rows for Codex and VS Code. See Decision 7.
- `llm_model`.
- The wording of the `conversation_id` description. That is a separate change.

## Decisions

### 1. The client's id wins over the SDK's handle

When a call carries both, `$session_id` comes from the client's id and the handle is ignored for
`$session_id` and `$mcp_conversation_id`. The SDK still strips the handle argument, which it owns.

The client sends its id on every call. A handle reaches the agent in the first call's result and
holds only while the agent copies it into each later call, so a conversation grouped by handle
splits whenever the agent drops or reuses the handle.
Taking the client's id whenever it is present makes every call of the conversation carry one key.
Taking the handle when present would mix the two keys within one conversation.

### 2. The id is hashed into `$session_id` and never sent as is

The SDK derives `$session_id` from `<key>:<value>` with the existing derivation. Prefixing the key
keeps ids from two clients from colliding. The value itself appears in no property: `$session_id`
carries all the grouping it gives, and the raw value would add an identifier to every event with no
further meaning. `$mcp_conversation_id` keeps its meaning (an SDK-minted UUIDv7 handle) and is unset
for these calls.

The 128-character printable ASCII bound matches the session token's `sid` and keeps the derivation
identical across languages, since the hash runs over characters.

### 3. Leaving `conversation_id` out of the listing (schema injection timing)

The SDK adds `conversation_id` at `tools/list`, before any call shows whether the client sends its own
id. The question is whether, and how, to leave it out for clients that do.

| Option | How the SDK knows | Tradeoff |
|---|---|---|
| A. Always advertise it; only skip the result block | No need to know | Simplest. The agent still sees a field the client already supplies, and some agents fill it with their own values. |
| B. Recognize the client per request at `tools/list` (**chosen**) | The table's recognition rule, read from the listing request | The listing matches what the client needs. A missed match keeps today's behavior. A false match costs that client handle anchoring only. |
| C. Learn it from the first call that carries an id | A call's `_meta` | Too late: the listing comes first, and a stateless HTTP request has no session to remember it in. |
| D. Host option only (turn conversation anchoring off) | The host decides | Already exists. Loses grouping for every stateless client the server serves, not only the ones that send an id. |

For option B the SDK needs a signal present on the listing request. The candidates:

- `clientInfo` from `initialize`. A legacy stateful session has it, but a stateless HTTP request is
  bound to no handshake, and a 2026-07-28 client sends no `initialize`.
- `clientInfo` in a 2026-07-28 request's `_meta`. Present only on that revision.
- The HTTP `User-Agent`. Sent on every HTTP request of every revision by the clients that set one
  (fact 3).

The ChatGPT row uses `User-Agent`, written as one anchored regex so every SDK parses it the same way:
the header starts with the `openai-mcp/` token, and the first field of its parenthetical, split on `;`
or `,` and trimmed, is `ChatGPT` in any case. Other OpenAI surfaces share the `openai-mcp` token with
their own parenthetical (Context), so the regex keeps them out. ChatGPT runs in OpenAI's cloud and
connects to a server by URL, never by starting a local process, so a header rule loses nothing for it. Each row states its own recognition rule, so a client that is
reached over stdio can use a different signal.

Recognition changes only what the SDK advertises and mints. A valid handle that a recognized client
echoes still counts, so a listing cached from before this change keeps working.

A recognized client's call that lacks its id gets no handle either. Minting one would put the block
back in the results of the very client the rule is for, and that client's listing has no argument to
echo it through. Such a call falls back to the transport session, or to a fresh session.

A listing now depends on the requesting client. A cache that serves one client's listing to another
(the 2026-07-28 `cacheScope` result field allows a shared scope) either drops the argument for an
unrecognized client, which then loses anchoring, or shows it to a recognized one, which is today's
behavior. Neither corrupts data, so the spec adds no cache rule.

### 4. Client ids do not depend on the anchoring option

The SDK reads client conversation ids with conversation anchoring on or off. The option controls what
the SDK adds for the model to see: the argument, the handle, the result block. Reading an id the
client already sends adds none of these, so a host that turns anchoring off keeps the grouping of
every client that sends an id.

### 5. Virtual tool annotations

Earlier SDKs declared `readOnlyHint: true`, `idempotentHint: true`, and `openWorldHint: true`. Per the
`ToolAnnotations` definitions in the MCP schema:

- `readOnlyHint: false`. Each call sends an event to the server owner's PostHog project, which
  modifies its environment.
- `destructiveHint: false`. The update is additive. Nothing is deleted or overwritten.
- `idempotentHint: false`. A repeated call sends another event.
- `openWorldHint: false`. The event goes to one bounded project, not an open world of external
  entities.

The host cannot change them, because they describe what the SDK's own handler does.

### 6. `context` asks for a few words

The value is recorded as `$mcp_intent`, the purpose of the call. A few words carry that purpose.
Longer answers tend to restate the user's request, which adds conversation content and names the
redaction pass cannot catch. The rule covers the injected `context` only. `get_more_tools` declares
its own `context` argument for a missing-capability report, which is a report, not a purpose, and
keeps its description. The 2,048-character limit stays as the hard bound; the description sets
the expectation.

### 7. Only ChatGPT gets a row in this change

Codex and VS Code also send a conversation id, but a row for each needs answers this change does not
have:

- Codex's key `sessionId` is unprefixed, so another client could send a `sessionId` that means
  something else. The SDK reads a key from any request today. A Codex row needs reading gated on recognition,
  and recognition over stdio, where there is no `User-Agent`, needs `clientInfo`.
- VS Code sends a resource URI instead of a session id for chats that are not local. Whether that URI
  is stable for a conversation and fits 128 characters is not checked.

The table takes a row without a new rule, so each is a follow-up change once checked against a real
connection.

## Risks / Trade-offs

- ChatGPT conversations change how they are grouped. A conversation that was split by a dropped or
  reused handle becomes one session. Session counts for ChatGPT traffic go down and sessions
  get longer, which is the more accurate count.
- The recognition rule depends on ChatGPT's `User-Agent`. If it changes, the SDK falls back to
  advertising `conversation_id`, which is today's behavior.

## Open Questions

- Is `openai/session` constant across a whole ChatGPT conversation, and does it fit 128 printable
  ASCII characters? The reference documents only its type. The first SDK implementation checks this
  against a real ChatGPT connection.
