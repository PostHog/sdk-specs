## 1. Spec delta

- [x] 1.1 Modify **Session identity**: client conversation ids, their key table, precedence over the
  handle, and no handle for a recognized client
- [x] 1.2 Modify **Arguments the SDK injects**: no `conversation_id` in a recognized client's listing,
  and a few words of purpose in the `context` description
- [x] 1.3 Add **Virtual tool annotations**
- [x] 1.4 Modify **Manual capture**: the list step takes the listing's headers, the renumbered
  "Session identity" rules, and the client id in the lower-level method
- [x] 1.5 Add the matching scenarios to `acceptance/public/mcp-analytics.feature`

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add "Client conversation id" to Terminology
- [x] 2.2 Update the conversation anchoring row of the Configuration table
- [x] 2.3 Mark `$mcp_conversation_id` as unset on a call with a client conversation id in Property
  reference

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-js `@posthog/mcp`
- [ ] 4.2 posthog-python `posthog.mcp`
- [ ] 4.3 posthog-go `posthogmcp` and `posthogmcpsdk`
- [ ] 4.4 posthog-ruby
- [ ] 4.5 posthog-rs `posthog_rs::mcp`
- [ ] 4.6 posthog-sdk-test-harness: step bindings for the new scenarios
