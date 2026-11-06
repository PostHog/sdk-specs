## Why

Local evaluators can disagree with the flags service when an early-access feature uses `filters.feature_enrollment`. An enrolled person can receive false despite opting in, while an opted-out person can receive true from ordinary targeting. The backend rule is explicit, but the SDK contract does not describe it.

## What Changes

- Define the person-level enrollment property, exact enrolled values, and precedence over holdouts and release conditions.
- Require inconclusive local evaluation when the enrollment property is unavailable, preserving remote fallback and local-only behavior.
- Preserve inactive and experience-continuity guards, and restrict unresolved-reason precedence to applicable causes rather than skipped targeting.
- Distinguish unsupported group-enrollment implementations from missing person context in supported implementations.
- Cover single, bulk, dependency, inactive, continuity, skipped targeting, and person/group context behavior with acceptance scenarios.
- Sync the canonical local-evaluator specification and archive this change on the same branch.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: early-access enrollment decisions and missing-context handling.

## Impact

This is a canonical specification correction grounded in the flags service and the existing SDK inactive/continuity contract. [PostHog/posthog-python#1176](https://github.com/PostHog/posthog-python/pull/1176) implements person-aggregated enrollment but leaves group prerequisites ahead of enrollment; [#1194](https://github.com/PostHog/posthog-python/pull/1194) addresses that direct evaluation gap. Focused group-dependency paths may still defer when they cannot preserve person context. The audited Node and Ruby evaluators still ignore the enrollment marker and need separate SDK changes. SDKs that consume remotely evaluated flags do not need a local enrollment engine.

No SDK implementation, public method, request schema, dependency, or release artifact changes in this repository.
