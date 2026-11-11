## Why
Offline experiments need explicit per-item composites with reproducible input versions. The SDK contracts currently cover only caller-reported results.

## What Changes
Extend scorer management, formula validation, calculation declarations, dependency-safe chunks, and stored outcome receipts. Preserve ordinary upload compatibility and exact replay.

## Capabilities
### Modified Capabilities
- `ai-scorers`: Versioned compositions, dependencies, and read-scoped validation.
- `offline-evaluations`: Explicit calculations, indivisible composite groups, and outcome receipts.

## Impact
Python sync/async APIs and cross-SDK acceptance scenarios. Requires the backend changes in PostHog/posthog#132949; this is a contract update, not a deployment claim.
