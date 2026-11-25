## 1. Spec delta

- [x] 1.1 Modify **Observer-only instrumentation**: what instrumentation's `flush()` does, a client wrapper's flush and shutdown, bounded flushing, what "the SDK is flushed" means; one scenario for each flush style

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Run `openspec archive` to sync the delta and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-js: `PostHogMCP`'s `flush()` and `shutdown()` wait for its pending MCP captures
- [ ] 3.2 posthog-python: `flush()` waits for captures on every event loop, not only its own; `PostHogMCP.shutdown()` takes a deadline
- [ ] 3.3 posthog-ruby: `Analytics#flush` logs a failed client flush instead of raising, and passes a timeout
- [ ] 3.4 posthog-go and posthog-rs: add an MCP flush
- [ ] 3.5 posthog-sdk-test-harness: step bindings for the two new scenarios; an MCP adapter's `/flush` calls instrumentation's `flush()`
