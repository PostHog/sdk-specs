## Why

AI observability's Python SDK supports dataset management, scorer management, and offline evaluation uploads without corresponding cross-SDK contracts. Client libraries needs those contracts to review changes and implement compatible APIs in other server SDKs.

## What Changes

- Specify the three capabilities together, including their public surfaces, data and version identities, lifecycle, pagination, authentication, and recoverable errors.
- Derive requirements from `posthog-python` and the corresponding PostHog backend, with source revisions and verification evidence in the design.
- Add matching black-box acceptance scenarios and explicitly record missing harness bindings; do not opt unverified scenarios into the integration suite.
- Add the capabilities to the repository indexes, then sync and archive this change in the same PR.

## Capabilities

### New Capabilities

- `ai-datasets`: Dataset and item management, immutable history, revision-pinned reads, and conversion to evaluation items.
- `ai-scorers`: Typed scorer definitions, immutable configurations and versions, metadata, filtering, and concurrency.
- `offline-evaluations`: Project-bound experiment creation, resumable result uploads, acknowledgments, explicit lifecycle, and shared management-client transport/error behavior.

### Modified Capabilities

None.

## Impact

Adds specifications and acceptance scenarios in this repository. Python supplies the initial reference implementation; server SDKs adopting these capabilities may use native naming and asynchronous conventions while preserving the contract. The change does not implement an SDK port, evaluator execution, backend-only read/export APIs, or harness routes. Existing analytics capture contracts remain unchanged.
