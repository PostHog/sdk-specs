## 1. Spec delta

- [x] 1.1 Modify **Observer-only instrumentation**: what the handle's `flush()` does, a client wrapper's flush and shutdown, bounded flushing; one scenario for each flush style

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Run `openspec archive` to sync the delta and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-js: `PostHogMCP`'s `flush()` and `shutdown()` wait for its pending MCP captures
- [ ] 3.2 posthog-python: `flush()` waits for captures on every event loop, not only its own
- [ ] 3.3 posthog-go and posthog-rs: align flush with the new rule
- [ ] 3.4 posthog-sdk-test-harness: step bindings for the two new scenarios
