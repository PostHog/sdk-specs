## 1. Spec delta

- [ ] 1.1 Confirm each modified requirement is a full copied-and-edited block from `main`, with only the changes the proposal lists
- [ ] 1.2 Verify the body limit reads as deployment configuration — 2 MiB default, 10 MiB hosted — everywhere `traces` and `logs` mentioned 2 MB, including the oversize-body scenarios
- [ ] 1.3 Verify the `traceparent` and `tracestate` rules match W3C Trace Context: lowercase-only, `ff` invalid, version `00` exact, higher versions may extend; `tracestate` 32 members as validity and 512 characters as a trim target
- [ ] 1.4 Verify the shared clock basis is a SHOULD, scoped to local non-backdated parents, per local trace rather than per process

## 2. Validation

- [ ] 2.1 `openspec validate --specs --strict` passes
- [ ] 2.2 `openspec validate align-traces-with-node-reference --strict` passes

## 3. Downstream

- [ ] 3.1 Confirm posthog-js implements every rule here as of PostHog/posthog-js#4579, and the clock basis in PostHog/posthog-js#4908
- [ ] 3.2 Track the `resourceAttributes` precedence fix in posthog-js traces and metrics separately
