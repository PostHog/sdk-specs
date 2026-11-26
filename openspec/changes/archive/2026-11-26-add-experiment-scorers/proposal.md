## Why

PostHog can pin a run-level formula and derive an experiment score from retained item results.
The server SDK contracts need to define how callers select a version and manage its formula
and suite assignments.

## What changes

- Add an optional exact version override to offline experiment creation.
- Extend scorer management with scope, experiment formula inputs, and versioned suite defaults.
- Add shared acceptance scenarios for wire fidelity, replay, and assignment behavior.

## Capabilities

### Modified capabilities

- `offline-evaluations`
- `ai-scorers`

## Impact

Applies to server SDKs that implement offline evaluations and scorer management.
Backend implementation is in [PostHog/posthog#142387](https://github.com/PostHog/posthog/pull/142387).
