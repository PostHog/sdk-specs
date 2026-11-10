## 1. Evidence and proposal

- [x] 1.1 Read the public wire contract in posthog-sdk-test-harness 1.27.0 (`contracts/feature_flag_rules_v2`, contract 8.0.0): the response presence matrix, the `$feature_flag_called` and `$experiment_exposure` property projections, and the reader expectations for exposure.
- [x] 1.2 Read the existing flag specs on main: `feature-flag-called-tracker` (dedupe and minimal-event mode), `evaluate-flags` (lazy access tracking and the snapshot event control), `get-feature-flag`, `get-feature-flag-result` (per-call option), `is-feature-enabled`, `get-feature-flag-payload` and `bootstrap`.
- [x] 1.3 Reconcile with `add-typed-flag-values` (#104) and the open client-level event default change (#153), so this change works whichever lands first.
- [x] 1.4 Write the proposal, the design and the delta specs, and run `openspec validate add-experiment-exposure --strict`.

## 2. Settle the decisions

- [x] 2.1 Settle the decisions in `design.md` and record any change there. Settled in review; the changes are recorded in `design.md`.
- [x] 2.2 Update the delta specs for every decision that changes.
- [ ] 2.3 Confirm that experiment analysis reads the variant from `$feature_flag_variant` on SDK-sent exposures. Open: this is query work outside this repository.
- [x] 2.4 Reword the dedupe sentence of `add-typed-flag-values` "Typed reads share the flag-called event" to "the key a legacy read of the same flag uses". Done in that change, before either archives.
- [x] 2.5 Release a harness contract whose `$experiment_exposure` projection drops `$feature_flag_config_version`, `$feature_flag_rule_type`, `$feature_flag_reason_code` and `$experiment_exposure_source`, and point this change at it (posthog-sdk-test-harness 1.27.0, contract 8.0.0).
- [ ] 2.6 Release the harness contract that accepts a `$feature_flag_called` without rule fields for `targeting_match`, `rollout_miss`, `experiment_paused` and `holdout` (posthog-sdk-test-harness#101, contract 9.0.0), and point this change at it. Open: the contract is not released yet. The spec text already names it, so archiving does not wait for it.

## 3. Acceptance and discoverability

- [x] 3.1 Add `acceptance/private/experiment-exposure.feature` covering the trigger outcomes (split, variant value false, holdout, rollout exclusion, paused, targeted match, failed, malformed split, config version 1, older-server record), a typed read of the wrong type, the required and forbidden properties, the dedupe cases (repeat read, remote after local, A/A variants, new rule, groups, shared cache), the event decision (client-level and per-read), bootstrap, overrides and a throwing capture hook.
- [x] 3.2 Add attribution (including the absent `$feature_flag_reason`), dedupe-key and minimal-event scenarios to `acceptance/private/feature-flag-called-tracker.feature`.
- [ ] 3.3 Add the harness step bindings that set a v4 record with reason and rule metadata, and that inspect `$experiment_exposure`. Open: step bindings live in posthog-sdk-test-harness. The new scenarios keep the legacy `@both`, `@client` and `@server` tags, so the integration suite does not select them yet.
- [x] 3.4 Add "Experiment Exposure" to the capability index in `README.md`.
- [x] 3.5 When syncing, write the Purpose section of `openspec/specs/experiment-exposure/spec.md`, and update the prose of `openspec/specs/feature-flag-called-tracker/spec.md` (Behavior item 1, Interactions) so it points to the config version 2 dedupe key and to `experiment-exposure`.

## 4. Validation and archive

- [x] 4.1 Run `openspec validate add-experiment-exposure --strict` and resolve all issues.
- [x] 4.2 Archive the change so the canonical specs are synced in the same PR, then run `openspec validate --specs --strict`.

Validation: `openspec validate add-experiment-exposure --strict` passed before archiving, `openspec validate --specs --strict` passes, both acceptance features parse as Gherkin, and `git diff --check` is clean. These are specification checks, not executed SDK conformance tests.
