## 1. Contract

- [x] 1.1 Confirm the server contract in posthog/posthog #103077 and the SDK behavior in posthog-android #825.
- [x] 1.2 Confirm no existing spec covers `quotaLimited` for replay, and that browser replay uses the ingestion `429` path instead.
- [x] 1.3 Draft the quota-limiting requirement and five acceptance scenarios.
- [x] 1.4 Add `quotaLimited` to the remote-config wire-field table with a scenario.

## 2. Validation and archive

- [x] 2.1 Sync the deltas into `openspec/specs/`, preserving unrelated requirements and scenarios.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` was not run — the CLI is not installed in this environment. The delta and the synced specs were checked by hand against the format of the archived changes, and the diff was reviewed for parity between the delta requirement text and the canonical spec. These are specification checks, not executed SDK conformance tests.
