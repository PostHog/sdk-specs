## 1. Refresh-Bounded Omission Knowledge

- [x] 1.1 Add acceptance coverage that a clean omission suppresses later probes across identities until a successful definitions refresh.
- [x] 1.2 Cover successful changed, not-modified, and shared-cache refresh invalidation, plus failed-refresh retention.
- [x] 1.3 Cover same-identity retries after failed, quota-limited, and computation-error responses.

## 2. Concurrent Probe Coordination

- [x] 2.1 Add acceptance coverage that concurrent calls for the same cleanly omitted key share one existence probe.
- [x] 2.2 Add acceptance coverage that probes for unrelated missing keys can begin independently.

## 3. Validation

- [x] 3.1 Run strict OpenSpec validation for the completed specification.
