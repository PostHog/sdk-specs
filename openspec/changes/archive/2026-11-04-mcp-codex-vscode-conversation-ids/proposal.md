## Why

OpenAI Codex and VS Code name the conversation on every tool call, as ChatGPT does: Codex in
`_meta.sessionId`, VS Code in `_meta["vscode.conversationId"]`. The SDK reads only ChatGPT's key, so
their calls are grouped by the SDK's handle, which holds only while the agent copies it into each
call. Codex's key has no prefix, so the SDK cannot read it from every client the way it
reads `openai/session`.

## What Changes

- **Session identity**: the client table gains rows for Codex (`sessionId`) and VS Code
  (`vscode.conversationId`), and two columns: the value's shape, and whether the client still gets a
  handle as a fallback.
- The SDK reads a row's key only from a request that row's recognition rule recognizes. Recognition
  takes the `User-Agent` or the resolved client name, so a client reached over stdio is recognized too.
- A recognized client is *handle-free* only when its row says so (ChatGPT). Codex and VS Code keep the
  `conversation_id` argument and the handle for the calls that carry no id.
- Scenarios: the ChatGPT ones now name ChatGPT's `User-Agent`; new ones cover Codex, VS Code, the
  fallback, and a key sent by the wrong client.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Session identity**, **Arguments the SDK injects**, **Manual capture**, the
  Terminology list, and the Configuration table.

## Impact

Codex and VS Code calls that carry an id get their `$session_id` from it, so a conversation is one
session from its first call, and Codex sub-agents join their parent's session. Calls without an id
behave as today. ChatGPT's `openai/session` is now read only from a request with ChatGPT's
`User-Agent`. The SDKs implement this together with the ChatGPT row.
