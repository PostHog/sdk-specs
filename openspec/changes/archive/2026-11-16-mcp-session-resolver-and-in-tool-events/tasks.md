## 1. Spec delta

- [x] 1.1 Modify **Session identity**: the session resolver ranks first and leaves anchoring alone, the `"host"` session source, and custom events captured during and outside a call; two scenarios

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Configuration: a session resolver row
- [x] 2.2 Property reference: `$mcp_session_source` includes `"host"`

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change

## 4. Downstream follow-ups (separate changes, not this one)

- [ ] 4.1 posthog-js: report `"host"`; count a resolver call toward the 30-minute rotation; carry the resolver's session in a minted token
- [ ] 4.2 posthog-python: resolve identity before the tool body so in-tool custom events carry it
- [ ] 4.3 posthog-go, posthog-ruby and posthog-rs keep custom events in their call's session
- [ ] 4.4 posthog-sdk-test-harness: step bindings for the two new scenarios
