## 1. Spec

- [x] 1.1 Replace the client SDK request-identity reset in `capture` "Capture v1 request headers" with the retry isolation rule and its in-memory fallback.
- [x] 1.2 Add scenarios for a whole-request retry, a per-event retry and the eviction fallback.

## 2. Parity suite

- [x] 2.1 Add the whole-request and per-event scenarios to `migration/yaml-parity-v1/capture-analytics-v1-retry.feature`.

## 3. Validation and archive

- [x] 3.1 Run `openspec validate isolate-capture-v1-retries-from-new-events --type change --strict`.
- [x] 3.2 Sync the delta into `openspec/specs/capture/spec.md` and archive the change.
- [x] 3.3 Run `openspec validate --specs --strict --no-interactive`.
