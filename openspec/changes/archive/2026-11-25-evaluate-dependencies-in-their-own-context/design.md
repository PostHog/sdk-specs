## Context

`rust/feature-flags/src/flags/flag_matching.rs` in PostHog/posthog:

- `evaluate_all_feature_flags` builds a dependency graph and `evaluate_flags_with_overrides` evaluates `evaluation_stages` in dependency order.
- `get_match` evaluates each flag with the full request context. A condition selects its property map and bucketing key from its effective aggregation. A group condition whose group is not in the request is skipped, so a pure group flag resolves to `false`.
- The result is stored in `flag_evaluation_results`. A `flag_evaluates_to` filter compares only that stored value.
- `get_person_properties` and `get_group_properties` remove known-absent keys per scope.
- `PropertyFilter::group_filter_index` in `property_filter.rs` returns `self.group_type_index.or(effective_aggregation)`.

## Decisions

1. Evaluate a referenced flag with the top-level inputs and its own aggregation. This matches the service and the posthog-js implementation, and keeps a listing for one scope from resolving a filter on another.
2. A group dependency without its group resolves as `false`, as the service returns. SDKs already return `false` for a directly evaluated group flag without its group.
3. Resolve a group filter without an index to the condition's effective aggregation. This mirrors `group_filter_index`.
4. Alternative considered: make a cross-aggregation dependency inconclusive. It is safe but adds a `/flags` request for flags that can resolve locally, and still differs from the service.

## Open question

The existing scenario "Evaluator signals remote fallback when required context is missing" says a group flag evaluated "without group context" is inconclusive. The flags service and the Python, Node, and Ruby SDKs return `false` when the group key is not supplied, and are inconclusive only when the group key is supplied without the group properties a condition needs. This change does not edit that scenario. It should be clarified separately.
