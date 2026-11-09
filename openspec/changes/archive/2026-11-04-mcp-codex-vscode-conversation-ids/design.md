## Context

`2026-11-04-mcp-client-conversation-ids` added client conversation ids with one row, ChatGPT, and
listed Codex and VS Code as clients that also send one (its design.md, Context and Decision 7). This
change adds them. What their source shows, read at `main` (openai/codex 75424f8, microsoft/vscode
e0de62d):

- **Codex** sends `threadId` and `sessionId` in `_meta` on every MCP tool call
  (`codex-rs/core/src/mcp_tool_call.rs`, `with_mcp_tool_call_ids_meta`). `sessionId` is "the identity
  shared by the root thread and all descendant threads" (`core/src/session/session.rs`,
  `session_id()`): it equals the root thread's id, a sub-agent inherits it, and a resumed thread
  restores it from its rollout. Both are UUIDv7 (`Uuid::now_v7`). The CLI's HTTP `User-Agent` is
  `codex-mcp-client/<version>` (`codex-rs/rmcp-client/src/utils.rs`) and its client name is
  `codex-mcp-client` (`codex-rs/codex-mcp/src/rmcp_client.rs`).
- **VS Code** sends `vscode.conversationId` whenever a tool call comes from a chat session
  (`src/vs/workbench/contrib/mcp/common/mcpServer.ts`). The value is `chatSessionResourceToId`
  (`contrib/chat/common/model/chatUri.ts`): a local chat's session id, and for any other kind of
  chat session the resource URI as a string. A local chat's id is a `generateUuid()` UUID persisted
  with the chat (`chatServiceImpl.ts`); `getNewSessionUri()` can also mint `chat-<n>`, and whether
  one reaches a tool call is not established. Its `User-Agent` and client name are the product's long
  name (`api/common/extHostMcp.ts`, `mcpServerRequestHandler.ts`). The source holds the open-source
  build's name, `Code - OSS`; Microsoft's builds overlay their own. `Visual Studio Code` is observed
  among the User-Agents PostHog's MCP analytics classifies; `Visual Studio Code - Insiders` follows the
  same naming and is not observed.

## Goals / Non-Goals

**Goals:** Codex and VS Code calls grouped by their own ids; no client's key read from another client;
no loss of grouping for a client version or chat kind that sends no id.

**Non-goals:** Codex reached through other OpenAI surfaces (`openai-mcp/<version> (Codex)`), whose
`_meta` is not known; VS Code forks, which have their own product names; `threadId`.

## Decisions

### 1. `sessionId`, not `threadId`

A Codex conversation can spawn sub-agents, each a thread of its own with its own `threadId`, all
sharing the root's `sessionId`. Their tool calls are part of the root conversation, so they belong
in its session. `sessionId` also survives a resume, where it is restored from the rollout.

### 2. A key is read only from its own client

Codex's `sessionId` is a generic name; another client could send a `sessionId` that means something
else, and two such clients would then merge sessions. Gating each row's key on its recognition rule
removes that. The cost falls on ChatGPT's `openai/session`, which is now ignored from a request without
ChatGPT's `User-Agent`. That request is not recognized as ChatGPT, so it is not handle-free either: it
gets the argument and a handle, which is today's behavior. Gating only unprefixed keys would keep
`openai/session` from such a request, at the price of a second kind of key with its own rule; one rule
for every row is simpler, and its cost is a fallback, not lost data.

### 3. Recognition by `User-Agent` or client name

Codex and VS Code both reach servers over stdio as well as HTTP, and stdio has no `User-Agent`. The
client name resolved by "Client and server identity" (from a 2026-07-28 request's `_meta`, or from a
handshake bound to the request's transport session) covers stdio. Either signal recognizes the client.
Manual capture's call step therefore takes the handshake's `clientInfo` too, and its lower-level
method reads a client conversation id only when the caller passes what recognizes the client.

Rules ignore case and rows are checked in table order, so two SDKs reach the same row for any request,
including one whose `User-Agent` and client name match different rows.

### 4. A UUID-shaped value

Both clients' ids are UUIDs when they are conversation ids. Requiring the shape drops VS Code's
resource-URI values, which name non-local chat sessions in a provider-specific form whose length and
stability are not known, any `chat-<n>` id, whose random part is small enough to collide across
users, and the nil UUID, which any client might send as a placeholder, and drops anything a different client might send under `sessionId`. A dropped
value falls back to the handle. UUIDs are compared and derived lowercased so that one id derives one
session whichever case a client prints.

### 5. Codex and VS Code keep the handle as a fallback

ChatGPT documents `openai/session` among the `_meta` fields it provides on tool calls, and is one
hosted service that ships a single version, so the earlier change made it handle-free. Its open
question, whether every call carries a valid id, still stands; a call that does not falls back to the
transport session or a fresh session.
Codex and VS Code are installed software: versions older than the source read here may send no id,
and VS Code sends a non-UUID value for non-local chats. If they were handle-free, those calls would
lose the only grouping a stateless HTTP request has. Keeping the argument costs one optional argument
in their listings; a call that carries an id still gets no result block, because the id wins over the
handle (Decision 1 of the earlier change). The table's Handle column makes this a per-row fact.

## Risks / Trade-offs

- A Codex conversation's sub-agent calls now join the parent's session, so Codex sessions get longer
  and fewer. That matches one root conversation per session.
- The recognition rules depend on product names and `User-Agent` prefixes. If either changes, the SDK
  stops reading the key and falls back to the handle, which is today's behavior.

## Open Questions

- Is `sessionId` sent by the Codex versions in use today? The first SDK implementation checks this
  against a released Codex, as it does `openai/session` against ChatGPT.
