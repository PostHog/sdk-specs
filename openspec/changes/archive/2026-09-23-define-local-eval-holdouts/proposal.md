## Why

Local evaluators can silently assign an experiment participant to a regular variant despite a holdout in the downloaded definition. Python fixed this in PostHog/posthog-python#978, but the SDK contract does not specify holdout behavior. The previous condition-selection change explicitly excluded holdouts.

## What Changes

- Specify holdout precedence, synthetic variant results, exact hashing, inclusive thresholds, clamping, and flag-level bucketing identity.
- Require holdout metadata to survive definition loading and supported caches.
- Skip holdouts with missing/null required fields, matching Python, and cover those inputs with acceptance examples.
- Add acceptance scenarios and apply/archive this change on the same branch.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: experiment holdout resolution and backend-compatible bucketing.
- `flag-definition-loader`: preserve holdout metadata through loading, caching, and refresh.

## Impact

The source audit found missing holdout evaluation in .NET, Java/Kotlin server (posthog-android), Go, Elixir, Node.js, Convex, PHP, Ruby, and Rust. Python main includes the fix. Mobile/browser SDKs consuming remote results and analytics plugins not enabling local evaluation do not need independent holdout engines. Implementation changes belong in the SDK repositories, not this repository.

## Non-goals

No SDK implementation, public API, remote evaluation protocol, or early-access enrollment changes. Other than skipping missing/null required fields, this change does not define recovery for malformed holdout fields.
