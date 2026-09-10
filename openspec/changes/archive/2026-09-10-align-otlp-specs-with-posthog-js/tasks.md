## 1. Spec delta

- [x] 1.1 Confirm each modified requirement is a full copied-and-edited block from `main`, with only the changes the proposal lists
- [x] 1.2 Verify the repeated-refusal rule states all three parts: extend on a later deadline, never pull in on a shorter one, bound by the documented maximum from first install
- [x] 1.3 Verify the OTLP divergences are both recorded — the window ceiling and the `408`/`5xx` retry set — each with its reason and its revisit condition
- [x] 1.4 Verify `logs` and `traces` carry the shared retry-policy paragraphs in identical words, including the budget-does-not-end-the-window rule and jitter
- [x] 1.5 Verify the traces-only retry rules sit in the paragraphs that already differ from `logs`: automatic sends pause during backoff, the budget counts backoff windows and belongs to the failing batch, and a dropped batch does not send the next one inside an open window
- [x] 1.6 Verify the body limit reads as deployment configuration — 2 MiB default, 10 MiB hosted — everywhere `traces` and `logs` mentioned 2 MB, including the oversize-body scenarios
- [x] 1.7 Verify the `traceparent` and `tracestate` rules match W3C Trace Context: lowercase-only, `ff` invalid, version `00` exact, higher versions may extend; `tracestate` 32 members as validity and 512 characters as a trim target
- [x] 1.8 Verify the shared clock basis is a SHOULD, scoped to local non-backdated parents, per local trace rather than per process

## 2. Validation

- [x] 2.1 `openspec validate --specs --strict` passes
- [x] 2.2 `openspec validate align-otlp-specs-with-posthog-js --strict` passes
- [x] 2.3 Run `openspec archive` to sync the delta into `specs/traces/spec.md` and `specs/logs/spec.md`

## 3. Downstream

- [x] 3.1 Confirm posthog-js implements every rule here as of PostHog/posthog-js#4579 (carrying #4726), and the clock basis in PostHog/posthog-js#4908
- [x] 3.2 Note for future ports: the window ceiling is required, not optional, wherever the window gates other triggers
