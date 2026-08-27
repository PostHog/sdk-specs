## Why

The local evaluator spec says that condition groups, rollouts, and variant overrides are evaluated, but it does not define how they are composed or selected. The Rust flags service and maintained server SDK evaluators now share ordered condition selection, `early_exit`, and per-condition person/group aggregation semantics that need a platform-neutral contract to prevent local and remote results from drifting.

## What Changes

- Define condition groups as ordered alternatives: filters within one group are ANDed, groups are tried in definition order, and the first matching group wins.
- Define rollout evaluation as a second gate after a group's property filters, including the narrow `early_exit` behavior for a targeted user who falls outside that group's rollout.
- Define how valid and invalid condition-level variant overrides affect the first matching group without reordering groups.
- Define per-condition person/group aggregation, including inheritance from legacy flag-level aggregation, explicit person aggregation, mixed targeting, and the identifier used for rollout and variant hashing.
- Define `flag_evaluates_to` dependency-filter matching for booleans and variant strings.
- Preserve local-evaluation uncertainty: missing required person, group, device, cohort, or dependency context remains inconclusive instead of becoming a definitive non-match.
- Add matching private acceptance scenarios.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Specify canonical condition-group composition, ordered selection, rollout short-circuiting, variant overrides, per-condition aggregation, and dependency-filter values.

## Impact

- Canonical spec: `openspec/specs/local-feature-flag-evaluator/spec.md`
- Acceptance documentation: `acceptance/private/local-feature-flag-evaluator.feature`
- Future server SDK conformance work where local selectors differ from the canonical Rust-backed behavior
- No public SDK signature or wire-format change
