## Context and sources

- The flags service's property type enum is `PropertyType` in `rust/feature-flags/src/properties/property_models.rs` in PostHog/posthog: `person`, `person_metadata`, `cohort`, `group`, and `flag`.
- `person_metadata` filters look up `__posthog_person_metadata__<key>` (`lookup_key_for` in `property_matching.rs`). The service writes that key from the persons-table column in `apply_person_cohort_to_state` (`flag_matching_utils.rs`), so a `created_at` person property never satisfies the filter.
- The flag filter API accepts only `person`, `cohort`, `group`, and `flag` (`FEATURE_FLAG_PROPERTY_TYPES` in `products/feature_flags/backend/api/filters_schema.py`). `person_metadata` reaches SDKs through cohort definitions, which the definitions endpoint sends unchanged.
- posthog-dotnet maps an unknown filter type to an unsupported filter and falls back (`src/PostHog/Json/FilterJsonConverter.cs`).

## Decisions

1. Defer, don't evaluate. An SDK has no persons-table value. The only local answer that can't contradict the flags service is inconclusive, so the flag falls back to `/flags`, or stays unresolved in local-only mode.
2. Use an allowlist, not a `person_metadata` special case. A filter type added to the flags service later carries the same risk: the SDK doesn't know where the service reads it from. The unrecognized-operator requirement already handles new operators this way.
3. Keep a filter without a `type` field as a person filter, and treat a JSON `null` or empty-string `type` the same way. Older stored definitions and SDK test fixtures omit the field, every SDK already treats it that way, and changing it would turn conclusive flags inconclusive. The flags service never sends any of the three, because its `type` field is required and the flag filter API rejects a missing type. Several SDKs decode `type` into a plain string and can't tell the three apart, so one rule for all of them avoids a type change for no behavior the service produces. Any other value is unsupported.
4. Report `unsupported_definition`. The cause comes from the definition, not from the call, so passing more context can't fix it. That matches how static cohorts and unrecognized operators are reported.
5. Check the type before the known-absent table. Known absence describes caller-supplied person and group properties. The flags service ignores a listed key with the person-metadata prefix, so listing `created_at` doesn't hide the persons-table value. A known-absent listing therefore doesn't resolve an unsupported filter, as it doesn't resolve an unsupported operator.
6. Keep the existing cohort composition rules. The inconclusive leaf is one input to three-valued AND/OR, so `false AND inconclusive` is still `false`. Negation and `not_in` don't invert it. Within a flag condition, a later filter that is definitively false still makes the condition a no-match.
7. Don't copy the flags service's test override. The service accepts the prefixed key from caller overrides, and its source says that's for testing. An SDK that matched local filters on that key would again let a caller supply persons-table data.

## Validation

`openspec validate --specs --strict` passes, and the delta in this archive matches the canonical spec.

## Risks

A flag whose cohort uses `person_metadata` now needs `/flags` in every call where that leaf decides the result. In local-only mode it stays unresolved instead of returning a value that can be wrong.
