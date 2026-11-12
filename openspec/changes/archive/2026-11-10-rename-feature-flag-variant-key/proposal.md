## Why

`$experiment_exposure` and the config version 2 `$feature_flag_called` event name the assigned variant in `$feature_flag_variant` (#162). For config version 2 flags the variant key and the flag value are separate: a split can assign the variant `control` with the value `false`, or the variant `boosted` with the value `25`. `$feature_flag_variant` reads like the value, which `$feature_flag_response` already carries. `$feature_flag_variant_key` names the arm identifier, matches its source field `metadata.variant_key`, and matches its sibling `$feature_flag_rule_id`.

No released SDK sends the property and nothing reads it yet. Renaming it now costs nothing; renaming it after an SDK ships would break every reader.

## What Changes

- **BREAKING** for in-progress implementations only: `$experiment_exposure` and the config version 2 `$feature_flag_called` event carry the variant key as `$feature_flag_variant_key` instead of `$feature_flag_variant`. Its value (`metadata.variant_key`), its presence rules and both dedupe keys do not change.
- `$feature_flag_response` does not change.
- The minimal-event allowlist for config version 2 attribution names `$feature_flag_variant_key`.
- `acceptance/private/experiment-exposure.feature` and `acceptance/private/feature-flag-called-tracker.feature` use the new name.
- The experiment-exposure applicability section names the harness contract that carries the new name.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `experiment-exposure`: **Experiment exposure trigger**, **Malformed experiment splits fail closed**, **Experiment exposure properties**, **Experiment exposure dedupe**, **Feature flag event decision covers the exposure**, **Bootstrapped and overridden values emit no exposure**, **Locally evaluated results** and **Exposure capture is built in one best-effort step**. Only the property name changes, plus one sentence in **Experiment exposure properties** on why the name ends in `_key`.
- `feature-flag-called-tracker`: **Minimal event mode for non-experiment flags**, **Config version 2 attribution on `$feature_flag_called`** and **Config version 2 dedupe key**. Only the property name changes.
- `evaluate-flags`: **Snapshot reads report experiment exposure**. Only the property name changes.

## Impact

- SDK implementations in review rename the property before they ship: posthog-python ([PostHog/posthog-python#1154](https://github.com/PostHog/posthog-python/pull/1154)) and posthog-node ([PostHog/posthog-js#5636](https://github.com/PostHog/posthog-js/pull/5636)).
- posthog-sdk-test-harness renames the property in `schemas/experiment_exposure_properties.schema.json` and `schemas/feature_flag_called_context.schema.json`, as contract 10.0.0 ([posthog-sdk-test-harness#105](https://github.com/PostHog/posthog-sdk-test-harness/pull/105)).
- The PostHog server does not read `$feature_flag_variant`. Experiment analysis of config version 2 flags (task 2.3 of the archived `add-experiment-exposure` change) reads `$feature_flag_variant_key`.
- The archived change `2026-11-05-add-experiment-exposure` keeps the old name as history.
