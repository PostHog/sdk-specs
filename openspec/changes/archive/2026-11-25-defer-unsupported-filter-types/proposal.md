## Why

A cohort can filter on Person metadata > First seen: `{"type": "person_metadata", "key": "created_at", ...}`. The flags service reads that value from the persons table under a separate key and never compares it with a `created_at` person property. Local evaluators in most SDKs treat every filter type other than `cohort` and `flag` as a person filter, so a caller that passes its own `created_at` person property gets a local result that can disagree with `/flags` (PostHog/posthog#137503).

The spec says unsupported cohort criteria are inconclusive and that unsupported behavior falls back to remote evaluation, but it doesn't say which filter types an SDK may match against caller-supplied properties. .NET already treats an unknown type as unsupported; the other SDKs don't.

## What Changes

- A new requirement lists the property-filter types a local evaluator matches: `person` and `group` against caller-supplied properties, `cohort` through cohort membership, and `flag` through dependency evaluation. A filter without a `type` field keeps its existing person-filter handling.
- Any other type, including `person_metadata` and a type added after the SDK shipped, is inconclusive with the `unsupported_definition` cause. The SDK never matches it against a caller-supplied property with the same key, and known absence doesn't resolve it.
- The rule applies to flag conditions and to dynamic-cohort leaves. Cohort negation and `not_in` don't turn the inconclusive leaf into a match, and three-valued composition still lets another leaf decide the group.
- Acceptance scenarios cover a `person_metadata` cohort leaf with and without a same-named caller property, a negated leaf, an unknown type in a flag condition, and a group where another leaf decides the result.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: adds the supported property-filter types requirement.

## Impact

A flag whose cohort uses a persons-table filter falls back to `/flags` instead of trusting a caller property. SDKs that treat any unrecognized type as a person filter need a small change: posthog-python, posthog-node, posthog-go, posthog-rs, posthog-ruby, posthog-php, posthog-elixir, and the JVM server SDK. .NET already conforms.

## Non-goals

Evaluating `person_metadata` locally. The SDK doesn't have the persons-table value, and accepting a caller-supplied value for it would reintroduce the bug.
