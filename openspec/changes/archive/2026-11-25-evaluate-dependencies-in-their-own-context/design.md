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

5. A group flag evaluated directly without its group key resolves as `false`, as the flags service returns. `get_match` skips a group-aggregated condition whose group type has no key in the request (`has_group_key`, reason `NoGroupType`), and a flag with no matching condition is `enabled: false`. The Python, Node, Ruby, and Elixir SDKs already do this. A supplied group key without the group properties a condition needs stays inconclusive, because the service would load stored properties that a local evaluator doesn't have. The scenario "Evaluator signals remote fallback when required context is missing" said a group flag evaluated "without group context" was inconclusive. It is replaced by one scenario for a missing group key (`false`) and one for a supplied key without the needed properties (inconclusive).

6. Use the flags service's definition of a usable group key. `is_usable_group_key` in `flag_matching.rs` accepts a non-empty JSON string or a JSON number. An omitted group type, an empty string, JSON null, a boolean, an array, or an object counts as no key, so a condition aggregated on that group type is skipped and a flag with no other matching condition is `false`. The earlier spec text made a non-string, non-number key inconclusive and treated an empty string as a key, which disagreed with the service and made the PHP and Python SDKs evaluate an empty-string key locally.