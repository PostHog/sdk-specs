## Why

Seven server SDKs now expose `evaluateFlags` / `evaluate_flags` as the preferred feature-flag API, but `sdk-specs` documents only the older single-flag getters, structured-result and bulk getters, and capture-time flag evaluation as separate capabilities. Without a canonical snapshot contract, readers and coding agents conflate `evaluateFlags(...)` with a renamed boolean check and miss that it supersedes those server-side call patterns: evaluate once, derive every flag view from an in-memory point-in-time snapshot, report exposure on access, and reuse the exact decisions during capture without another `/flags` request.

## What Changes

- Add a server-side `evaluate-flags` public API capability, grounded in the shipped Node, Python, Ruby, PHP, Go, .NET, and JVM server implementations.
- Define `evaluateFlags(...)` / `evaluate_flags(...)` as one evaluation operation that returns a reusable `FeatureFlagEvaluations` snapshot for one resolved identity and evaluation context.
- Define the snapshot's value, enablement, payload, key enumeration, access tracking, and filtering behavior.
- Specify that snapshot reads never re-evaluate flags or perform network I/O; map older boolean, value, payload, structured-result, bulk, and capture-time evaluation APIs to their snapshot replacements.
- Specify lazy `$feature_flag_called` behavior: creating a snapshot emits no exposure event; `isEnabled(...)` and `getFlag(...)` record access and emit through the normal dedupe tracker; payload-only reads remain silent.
- Specify snapshot reuse during `capture(flags: snapshot)`, including exact decision consistency, no additional flag-evaluation request, and in-memory `only(...)` / `onlyAccessed()` filtering.
- Specify request-time key filtering separately from in-memory snapshot filtering, plus local-only evaluation, missing-identity, disabled-client, and partial/failure fallbacks.
- Add public acceptance scenarios and the capability to the root index.

## Capabilities

### New Capabilities

- `evaluate-flags`: Server-side point-in-time feature-flag evaluation snapshots, their accessors and exposure side effects, and reuse for event enrichment without repeated evaluation.

### Modified Capabilities

None. The existing `is-feature-enabled`, single-flag getter, bulk getter, capture, and feature-flag-called-tracker requirements remain valid; the new capability defines the newer server-side composition that connects them.

## Impact

- Adds a canonical target for the server SDKs in `posthog-js/packages/node`, `posthog-python`, `posthog-ruby`, `posthog-php`, `posthog-go`, `posthog-dotnet`, and `posthog-android/posthog-server`; known convergence gaps are documented for Node override filtering, .NET local/cache request filtering, GeoIP control, and empty-before-access filtering, plus JVM partial-result preservation.
- Clarifies that the snapshot supersedes the older server-side getter/capture-time evaluation family, while client SDKs' ambient-cache `isFeatureEnabled(...)` APIs are not replaced by this server-only contract.
- Interacts with `is-feature-enabled`, `get-feature-flag`, `get-feature-flag-payload`, `get-feature-flag-result`, `get-feature-flags`, `get-feature-flags-and-payloads`, `capture`, `feature-flag-called-tracker`, `local-feature-flag-evaluator`, `http-client`, and `tracing-headers`.
- Adds `acceptance/public/evaluate-flags.feature` and a `README.md` capability entry; no SDK implementation code changes in this repository.
