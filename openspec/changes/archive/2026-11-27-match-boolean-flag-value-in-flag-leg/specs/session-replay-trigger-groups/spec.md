## MODIFIED Requirements

### Requirement: Flag leg

A group's `flag` leg SHALL be satisfied by the same rules as the V1 linked flag in
`session-replay-ingestion-controls`, applied to the resolved flag value. When the value is a
boolean, the leg is satisfied by `true` and not by `false`, whether or not the leg configures a
variant. When the value is a string, a `{ flag, variant }` object is satisfied only when the value
equals that variant, and a flag key with no variant is satisfied by any non-empty string. A missing
or quota-limited flag is not satisfied. A boolean `true` with a configured variant occurs when a
flag changes from multivariate to boolean after the group was saved, because nothing clears the
stored variant; the leg is then satisfied and recording continues. The SDK SHALL read the flag
value from the loaded flags and SHALL NOT capture `$feature_flag_called` when it evaluates the leg.
The leg is re-evaluated when feature flags change.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:580` constructs a
`LinkedFlagMatching` per group and `:605` feeds it `linkedFlag: group.conditions.flag`, so the
group reuses the V1 matcher unchanged). At posthog-js `origin/main` `c8f17c663a`,
`triggerMatching.ts:447` reads the flag from the `variants` map that `onFeatureFlags` passes to
its callback. `$feature_flag_called` is captured only by `getFeatureFlag` (`posthog-core.ts:2771`,
`send_event`), and nothing under `packages/browser/src/extensions/replay/` calls it.

The boolean value with a configured variant: posthog-js `origin/main` `8514edc7c`
`triggerMatching.ts:452-458` checks `isBoolean(variantForFlagKey)` before it compares
`linkedVariant`, so a boolean value decides the match whatever variant is configured.
posthog-android `origin/main` `2096bec46`
(`posthog/src/main/java/com/posthog/internal/replay/PostHogTriggerGroupsEvaluator.kt:325`,
`is Boolean -> value`) and posthog-ios `origin/main` `e0a11adb99`
(`PostHog/Replay/PostHogTriggerGroupsEvaluator.swift:260-261`) do the same. Why the case is
reachable, at posthog `origin/master` `fa4a501d8c`: the flags service returns boolean `true` only
for a match with no variant (`rust/feature-flags/src/flags/flag_matching.rs:139-143`), variant
rollout percentages must sum to 100 (`products/feature_flags/backend/filters_validation.py:82-88`),
and the UI offers a variant only for a multivariate flag
(`frontend/src/lib/components/IngestionControls/triggers/FlagTrigger/VariantSelector.tsx:63`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:97`
("should create matcher with feature flag" — boolean form). The `{ flag, variant }` form inside a
group: No posthog-js test on `origin/main` covers this; decision-based (the source reuses
`LinkedFlagMatching`, whose variant handling the V1 requirement already covers). Boolean `true`
with a configured variant: No posthog-js test on `origin/main` covers this; source only.

#### Scenario: A boolean flag leg activates a group
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with boolean flag condition "replay-flag" and a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: A flag leg with a variant must match the variant
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with flag condition "replay-flag" variant "test" and a sample rate of 1.0
- **AND** feature flag "replay-flag" resolves to variant "control" for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: A boolean true flag value satisfies a flag leg with a variant
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with flag condition "replay-flag" variant "test" and a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Evaluating a flag leg captures no $feature_flag_called event
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with boolean flag condition "replay-flag" and a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active
- **AND** no `$feature_flag_called` event for "replay-flag" should be captured
