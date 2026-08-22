## Why

A requested key that is missing both locally and remotely can currently trigger one `/flags` request on every evaluation call in Python, Node.js, Go, and .NET. This makes deleted flags, stale application references, and typos scale billed remote evaluation traffic with application traffic even though a successful response already proved that the key was absent.

## What Changes

- Require SDKs with a successful local-definition refresh lifecycle to retain a clean remote omission in a finite-capacity store until the next successful refresh or capacity eviction.
- Require suppression to clear after modified, unchanged or `304`, and successful shared-cache definition refreshes, and reject stale in-flight omission results from an earlier definitions generation.
- Keep failed, quota-limited, and computation-error responses ineligible to establish suppression, and require a later evaluation to retry.
- Require concurrent first probes for the same cleanly omitted key to share one in-flight request while allowing disjoint missing-key sets to proceed independently, preserving original scope for mixed overlapping calls, and never sharing returned identity-specific values across contexts.
- Keep the first missing-key fallback, original request scope, local-wins merge, result filtering, and local-only behavior unchanged.
- **BREAKING**: This changes refresh-capable SDKs from optional per-call probing to a bounded request contract.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: Require refresh-bounded missing-key knowledge and per-key concurrent probe coordination for SDKs that refresh local definitions.

## Impact

The audited server SDK implementations currently differ:

| SDK | Current behavior | Required implementation change |
|---|---|---|
| Android | Retains clean omissions until every successful definitions refresh, invalidates modified, `304`, and shared-cache loads, coalesces same-key probes, keeps unrelated keys concurrent, and retries inconclusive probes. Its retained-key sets do not currently have an explicit capacity bound. | Add a finite capacity or eviction policy to the retained-key state. It remains the behavioral reference implementation. |
| Python | Makes one scoped fallback per evaluation call and retains no missing-key knowledge. | Add finite-capacity, refresh-scoped clean-omission state and same-key in-flight coordination. |
| Node.js | Makes one scoped fallback per evaluation call and retains no missing-key knowledge. | Add finite-capacity, refresh-scoped clean-omission state and same-key in-flight coordination. |
| Go | Makes one scoped fallback per evaluation call and retains no missing-key knowledge. | Add finite-capacity, refresh-scoped clean-omission state and same-key in-flight coordination. |
| .NET | Deliberately bypasses the general cache for scoped calls and makes one direct request per call because the public cache key omits request scope. | Add finite-capacity internal refresh-scoped omission state and probe coordination without changing `IFeatureFlagCache`. |

The change affects the canonical evaluate-flags specification and public acceptance coverage. SDK implementation PRs can follow after this behavior is accepted.
