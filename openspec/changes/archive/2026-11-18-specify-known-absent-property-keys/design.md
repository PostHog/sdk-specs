## Context and sources

The flags service behavior comes from PostHog/posthog issue #88947 and PostHog/posthog#138239. This change copies its contract into the SDK spec so local evaluation matches it.

## Decisions

1. Place the `/flags` request contract in `local-feature-flag-evaluator` as a new requirement, "Remote fallback carries known-absent keys". The fields exist only so remote fallback agrees with local evaluation, and the existing spec already defers the "corresponding `/flags` request contract" to this capability. No spec in this repository describes the `/flags` request body as a whole, so a new capability would hold a single paragraph and need a README row. Revisit if more request fields need a shared home.
2. Describe the SDK input abstractly: a set of person property keys, and per group type a set of group property keys, known to be absent for this evaluation. Per-language option names are left to SDK repositories.
3. Make the input optional (`MAY`). SDKs without it keep today's behavior.
4. The listing wins over a supplied value for the same key, matching the server, so a caller cannot get contradictory local and remote results.
5. Use one result table for operators on a known-absent key: `is_not_set` and the negated operators match, and everything else does not, including `semver_neq` and the `is_date_*` operators. This mirrors the server. The table is stated once in the canonical operator inventory requirement, and the equality, string-search, and multi-contains requirements point to it.
6. Known absence does not change cohort membership read from stored tables, holdouts read no properties, and flag dependencies honor it because they evaluate with the same listing.
7. Ignore listed person keys that carry the person-metadata prefix `__posthog_person_metadata__`, so known absence never hides the persons-table `created_at` column.
8. State the server limits (1000 strings per array, counted with duplicates and per group type, HTTP 400 naming the field) in the spec because an SDK that exceeds them fails the fallback request. The SDK-side advice to validate the limit before sending, and never to truncate, is an addition of this spec and not server behavior.
9. Treat a listed enrollment property `$feature_enrollment/<flag key>` as known absent, not as missing context. The flags service removes it, treats the person as not enrolled, and continues through holdouts and release conditions as for any person without the enrollment property. The spec changes the "Unavailable enrollment context remains inconclusive" requirement so the inconclusive rule applies only when the property is omitted and not listed.
10. Make `between` and `not_between` follow HogQL. Flag evaluation should agree with analytics where it can. HogQL (`posthog/hogql/property.py`) reads a property value that does not convert to a number as NULL, so `not_between` matches it. The flags service copies that rule, and a test in each codebase checks the same cases (`test_between_operators_treat_uncoercible_value_as_out_of_range` and `test_match_properties_between_operator_uncoercible_values`). The earlier spec text said neither operator matches such a value, which disagreed with both engines and with the known-absent result for `not_between`. NaN matches neither operator in both engines. Both engines also accept infinite values and bounds, so the spec allows them for the range operators. The `gt`, `gte`, `lt`, and `lte` rules are unchanged.
11. Check operator support before the known-absent table. No local-evaluation SDK implements `between`, `not_between`, `icontains_multi`, or `not_icontains_multi` yet. If an SDK applied the table first, a listed key would resolve one of those operators locally, though the SDK cannot evaluate it. Checking support first keeps such a flag `unsupported_definition`, so it falls back to `/flags`, which receives the listing and returns the right result.

## Validation

The scenarios cover: a listed key with `is_not_set`, a listed key with `is_set`, a supplied value overridden by the listing, group-type scoping, an unlisted omitted key, a person-metadata key, negated operators, and the remote fallback request body. Gherkin scenarios in `acceptance/private/local-feature-flag-evaluator.feature` mirror them. `openspec validate --specs --strict` passes, and the synced canonical spec matches the delta text.

## Risks

An SDK that lists a key as absent when the person actually has the property produces results that differ from stored data. That is the caller's responsibility and is why the input is explicit.
