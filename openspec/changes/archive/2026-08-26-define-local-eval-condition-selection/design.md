## Context

The refreshed backend reference is PostHog `master` at `55be8f3f6a949ac5588d55e135c5da037a936cd0`. The relevant Rust selector in `rust/feature-flags/src/flags/flag_matching.rs` walks condition groups in stored order, evaluates filters before rollout, applies `early_exit` only to `OutOfRolloutBound`, returns the first matching group, and resolves condition variant overrides. `flag_property_group.rs` preserves three aggregation states: field absent, explicit person (`null`), and explicit group index.

The existing SDK spec only says to evaluate property filters, rollouts, overrides, and dependencies. It does not define their composition. Maintained Python, Node, Go, Ruby, and PHP server SDK evaluators already mirror substantial parts of the Rust selector, so the missing contract can cause future ports and audits to accept incompatible results.

## Goals / Non-Goals

**Goals:**

- Specify condition-group composition and deterministic first-match selection.
- Specify the narrow meaning of `early_exit`.
- Specify condition-level variant override handling.
- Specify per-condition aggregation, mixed person/group filters, and bucketing identity.
- Specify dependency-filter comparisons for boolean and multivariate flag values.
- Preserve local fallback when no definitive result can be selected from the available context.
- Add executable-style acceptance documentation for the selector branches most likely to drift.

**Non-Goals:**

- Enumerate every property operator; existing operator requirements remain authoritative.
- Standardize backend-only match-reason descriptions or condition-analysis metadata.
- Specify holdout or early-access enrollment selectors in this change.
- Change any SDK implementation, flag-definition wire shape, or public API.

## Decisions

### Model selection as ordered OR groups containing AND filters

Condition groups SHALL remain in their definition order. All filters in one group must match, then its rollout gate must include the effective bucketing identifier. The first group satisfying both gates determines the flag. A condition-level variant override does not move that group ahead of earlier groups.

This matches the Rust loop and avoids the historical alternative of sorting variant-override groups first. It also makes variant and payload selection deterministic when more than one group could match.

### Distinguish property mismatch from rollout exclusion

A property mismatch is an ordinary non-match and evaluation continues. `early_exit` applies only after every filter in the current group matched and that group's rollout excluded the identifier. In that case, the selector returns disabled without evaluating later groups. An absent `early_exit` is false.

Local evaluation can additionally encounter unavailable context. Such a condition is inconclusive, not an `early_exit` trigger. The evaluator may continue looking for a definitive matching group; if no group determines a value and at least one condition was inconclusive, the flag remains inconclusive and remote fallback stays eligible.

### Preserve the three aggregation states on the definition wire

For each condition:

- omitted `aggregation_group_type_index` inherits the flag-level aggregation for legacy definitions
- explicit `null` selects person aggregation
- an integer selects that group type

Property source follows each filter's type, so one condition may AND person and group filters. The condition aggregation controls rollout and variant hashing: person conditions use the person bucketing identifier, while group conditions use the selected group key. This follows the Rust `PropertyContext`, `effective_aggregation`, rollout, and variant paths rather than treating the whole flag as permanently person- or group-scoped.

### Compare dependency filters against evaluated flag values

A `flag_evaluates_to` filter participates in the condition's AND composition. Expected `true` matches an enabled boolean or any multivariate variant, expected `false` matches only boolean false, and an expected variant string matches only that exact string. Missing definitions, unresolved dependencies, and cycles remain locally inconclusive for the dependent flag instead of adopting the Rust response layer's backend-only fail-closed policy.

This captures the value contract in `flag_matching_utils.rs` without standardizing the Rust dependency graph, staging, or cache implementation.

### Validate selector behavior with focused scenarios

The private acceptance feature will cover ordered first-match behavior, AND/OR composition, all important `early_exit` branches, condition-level aggregation inheritance/override, mixed person/group routing, missing device context, and dependency values. Operator-specific and general missing-property scenarios remain in their existing requirements.

## Risks / Trade-offs

- [Some SDKs implement only part of mixed targeting] → Scope the scenarios to definition-based server local evaluation and use the contract to drive later conformance work rather than weakening the canonical behavior.
- [JSON libraries may collapse omitted and explicit-null fields] → State the semantic distinction explicitly; implementations may use an option wrapper, presence bit, raw-map membership check, or equivalent platform idiom.
- [A broad selector requirement could duplicate operator rules] → Keep operator truth tables out of this change and reference the existing operator requirements.
- [Backend evaluation has authoritative stored properties while SDK evaluation often has partial context] → Keep unavailable SDK context inconclusive when no definitive match is selected; do not copy backend-only fail-closed details into the local contract.
