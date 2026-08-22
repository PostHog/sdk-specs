## 1. Refresh-Bounded Omission Knowledge

- [x] 1.1 Add acceptance coverage that a clean omission suppresses later probes across identities until a successful definitions refresh.
- [x] 1.2 Cover successful changed, not-modified, and shared-cache refresh invalidation, plus failed-refresh retention.
- [x] 1.3 Cover same-identity retries after failed, quota-limited, and computation-error responses.
- [x] 1.4 Cover changed, not-modified, and shared-cache refreshes invalidating a delayed probe from the previous definitions generation.
- [x] 1.5 Define finite-capacity retention and make evicted keys eligible for a fresh probe.

## 2. Concurrent Probe Coordination

- [x] 2.1 Add acceptance coverage that concurrent calls for the same cleanly omitted key share one existence probe.
- [x] 2.2 Add acceptance coverage that probes for disjoint missing-key sets can begin independently.
- [x] 2.3 Cover mixed scopes that overlap an in-flight probe while preserving the caller's original request scope.
- [x] 2.4 Cover returned keys being evaluated separately when distinct ID, device ID, groups, properties, GeoIP control, or requested scope differs.

## 3. Validation

- [x] 3.1 Run strict OpenSpec validation for the completed specification.
