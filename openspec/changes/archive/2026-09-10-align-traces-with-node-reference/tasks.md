## 1. Spec delta

- [x] 1.1 Confirm each modified requirement is a full copied-and-edited block from `main`, with only the changes the proposal lists
- [x] 1.2 Verify the body limit reads as deployment configuration — 2 MiB default, 10 MiB hosted — everywhere `traces` and `logs` mentioned 2 MB, including the oversize-body scenarios
- [x] 1.3 Verify the `traceparent` and `tracestate` rules match W3C Trace Context: lowercase-only, `ff` invalid, version `00` exact, higher versions may extend; `tracestate` 32 members as validity and 512 characters as a trim target
- [x] 1.4 Verify the shared clock basis is a SHOULD, scoped to local non-backdated parents, per local trace rather than per process

## 2. Validation

- [x] 2.1 `openspec validate --specs --strict` passes
- [x] 2.2 `openspec validate align-traces-with-node-reference --strict` passes
- [x] 2.3 Run `openspec archive` to sync the delta into `specs/traces/spec.md` and `specs/logs/spec.md`

## 3. Downstream

- [x] 3.1 Confirm posthog-js implements every rule here as of PostHog/posthog-js#4579, and the clock basis in PostHog/posthog-js#4908

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 **posthog-js** — traces and metrics resolve `serviceName` as `resourceAttributes["service.name"] ?? serviceName` (`resolveTracesConfig`, `resolveMetricsConfig`), so a `resourceAttributes` value overrides the configured service name, against the **Resource and scope** requirement and the `logs` behavior. Make the configured `serviceName`, `serviceVersion` and `environment` win
- [ ] 4.2 **`logs` attribute encoding** — state the empty-key drop in the `logs` capability too; posthog-js already applies it to logs through the shared encoder
