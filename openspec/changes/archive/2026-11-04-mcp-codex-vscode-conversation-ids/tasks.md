## 1. Spec delta

- [x] 1.1 Modify **Session identity**: Codex and VS Code rows, the Value and Handle columns, reading a
  key only from its own client, and handle-free clients
- [x] 1.2 Modify **Arguments the SDK injects**: leave `conversation_id` out only for a handle-free client
- [x] 1.3 Modify **Manual capture**: the call step takes the handshake's `clientInfo`, and the
  lower-level method reads a client conversation id only with what recognizes its client
- [x] 1.4 Update the matching scenarios in `acceptance/public/mcp-analytics.feature`

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Say "handle-free client" in the conversation anchoring row of the Configuration table
- [x] 2.2 Scope "Client conversation id" in Terminology to a key read from its own client

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 The SDK implementations of `2026-11-04-mcp-client-conversation-ids` include these rows
- [ ] 4.2 posthog-sdk-test-harness: step bindings for the `User-Agent` and clientInfo variants of the
  `_meta` call step
