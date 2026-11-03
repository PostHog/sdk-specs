## 1. Spec delta

- [x] 1.1 Modify the **Arguments the SDK injects** requirement as a full copied-and-edited block
- [x] 1.2 Define call-time ownership resolution for fresh low-level server instances
- [x] 1.3 Define the host resolver fallback and its fail-open behavior
- [x] 1.4 Add a strict-schema scenario that does not serve `tools/list` on the call instance

## 2. Acceptance coverage

- [x] 2.1 Add the fresh low-level server scenario to the public MCP Analytics feature

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict`
- [x] 3.2 Run `openspec archive` to sync the delta and archive the change
