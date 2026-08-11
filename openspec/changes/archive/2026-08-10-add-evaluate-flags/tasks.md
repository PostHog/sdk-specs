## 1. Cross-SDK evidence

- [x] 1.1 Audit the shipped snapshot APIs in Node, Python, Ruby, PHP, Go, .NET, and the JVM server SDK.
- [x] 1.2 Compare evaluation inputs, local/remote fallback, snapshot accessors, exposure tracking, payloads, capture enrichment, filtering, and safe fallback behavior.
- [x] 1.3 Record real divergences and select a canonical target or explicit platform variation for each.

## 2. Specification

- [x] 2.1 Add the `evaluate-flags` server-side public capability delta spec.
- [x] 2.2 Define the evaluate-once/read-many point-in-time snapshot contract and distinguish snapshot `isEnabled(...)` from direct `isFeatureEnabled(...)` evaluation.
- [x] 2.3 Define flag values, payloads, keys, evaluation metadata retention, lazy `$feature_flag_called`, and missing-value behavior.
- [x] 2.4 Define exact snapshot reuse during capture with no additional flag-evaluation request.
- [x] 2.5 Define request-time key filtering separately from `only(...)` / `onlyAccessed()` in-memory filtering.
- [x] 2.6 Define no-identity, disabled-client, local-only, remote-failure, and partial-snapshot behavior with host-language error latitude.
- [x] 2.7 Map superseded server boolean, value, payload, structured-result, bulk, and capture-time evaluation APIs to snapshot replacements.

## 3. Acceptance and discoverability

- [x] 3.1 Add public server acceptance scenarios for one-request reuse, accessor projections, lazy exposure tracking, payload silence, capture reuse, filtering, and missing identity.
- [x] 3.2 Add Evaluate Flags to the root capability index next to the other feature-flag public APIs.
- [x] 3.3 Ensure the spec explicitly states that client ambient-cache `isFeatureEnabled(...)` remains a different API and that older server getter/capture-time evaluation methods are compatibility surfaces.

## 4. Validation and archive

- [x] 4.1 Run `openspec validate add-evaluate-flags --strict` and resolve all issues.
- [x] 4.2 Run `openspec validate --specs --strict` before archiving.
- [x] 4.3 Archive the completed change so the canonical spec and archived proposal are included in the same branch.
- [x] 4.4 Review the final diff against shipped behavior and address concrete findings.
