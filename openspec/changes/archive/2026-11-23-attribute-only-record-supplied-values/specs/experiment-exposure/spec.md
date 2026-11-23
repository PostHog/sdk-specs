## MODIFIED Requirements

### Requirement: Experiment exposure trigger

A tracked read is a flag read on a path that reports `$feature_flag_called` and whose feature flag event decision is `true`. Every tracked read SHALL keep reporting `$feature_flag_called` as the existing requirements define. The same read SHALL also emit one `$experiment_exposure` event, subject to "Experiment exposure dedupe", when the evaluation details that supplied the read's value meet all of these conditions:

- the record was read without a parse error and is not `failed`;
- `metadata.config_version` is 2;
- `reason.code` is `experiment_split`;
- `metadata.rule_type` is `experiment`;
- `metadata.rule_id` is present;
- `metadata.variant_key` is present;
- the record supplied the value the read reports. A bootstrapped value, a client-side override, a caller-supplied match value and a stale cached value did not come from the record (see "Values the record did not supply are reported as config version 1" in `feature-flag-called-tracker`).

"Present" means the member exists and is not `null`. A rule ID counts as present only when it is a string in the hyphenated 8-4-4-4-12 hexadecimal UUID form, the form the event schemas require; any other string counts as a missing rule ID. This applies to every read path that reports `$feature_flag_called`: client getters such as `getFeatureFlag`, `isFeatureEnabled` and `getFeatureFlagResult`, server single-flag getters, snapshot enablement and value reads (see `evaluate-flags`), and typed value or details accessors where the SDK has them. Whether a read is tracked is decided as the existing requirements and "Feature flag event decision covers the exposure" define. The two events dedupe independently: a tracked read whose `$feature_flag_called` the tracker suppresses as a repeat SHALL still emit the exposure when the exposure key is new, and a tracked read whose exposure key is already present SHALL still emit `$feature_flag_called` when its tracker key is new.

The trigger SHALL NOT depend on whether an experiment links to the rule. `metadata.has_experiment`, and any experiment the SDK knows about, are not inputs.

No other outcome SHALL emit `$experiment_exposure`: not a targeting match, a percentage rollout match, a terminal rollout miss (including an experiment rule's rollout exclusion), a holdout, a paused experiment, a no-rule match or flag default, a missing flag, a failed or unreadable record, a bootstrapped value, a client-side override, a caller-supplied match value, a stale cached value, a config version 1 record, or a record from a server that does not send typed values (which reads as config version 1).

The decision SHALL use the evaluation details that supplied the value, not the value the read returned. A read that returned a caller-supplied default instead of the flag's value, because the value is `null` or is `false` read as another type, SHALL still emit the exposure when the details meet the conditions. A variant whose value is `false` is still an assignment.

A typed read that returned the caller default because the value has another type than the read asks for (a type mismatch) SHALL emit neither `$feature_flag_called` nor `$experiment_exposure`, and SHALL NOT consult or update either dedupe namespace, so the next read of the right type emits both. The SDK logs the mismatch instead, as the typed accessors define.

#### Scenario: An experiment split emits both events
- **GIVEN** the record for "checkout-flow" has value true, no `failed` member, reason code `experiment_split`, and metadata config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** exactly one `$feature_flag_called` event is enqueued for "checkout-flow"
- **AND** exactly one `$experiment_exposure` event is enqueued for "checkout-flow" with `$feature_flag_variant_key` "test" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"

#### Scenario: A variant whose value is false is still exposed
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "control" and value false
- **WHEN** an enablement read of "checkout-flow" returns false and emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued with `$feature_flag_variant_key` "control" and `$feature_flag_response` false

#### Scenario: A holdout emits no exposure
- **GIVEN** the record for "checkout-flow" has value false, reason code `holdout`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13", and no variant key
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A terminal rollout exclusion emits no exposure
- **GIVEN** the record for "checkout-flow" has value false, reason code `rollout_miss`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13", and no variant key
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A paused experiment emits no exposure
- **GIVEN** the record for "checkout-flow" has value false, reason code `experiment_paused`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13", and no variant key
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A targeted match emits no exposure
- **GIVEN** the record for "beta-ui" has value true, reason code `targeting_match`, config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A failed record emits no exposure
- **GIVEN** the record for "checkout-flow" has `failed` true, reason code `error` and config version 2
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A config version 1 experiment flag gets no SDK exposure
- **GIVEN** the record for "legacy-layout" has value "compact", config version 1, `has_experiment` true and variant key "compact"
- **WHEN** a read of "legacy-layout" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued
- **AND** the `$feature_flag_called` event has no `$feature_flag_config_version` property

#### Scenario: A record from a server that does not send typed values gets no SDK exposure
- **GIVEN** the record for "legacy-layout" has `enabled` true, `variant` "compact" and no `value`
- **WHEN** a read of "legacy-layout" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

#### Scenario: A read that returns its caller default for a false variant still reports the assignment
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** an accessor that asks for a string value reads "checkout-flow" with caller default "blue"
- **AND** it returns "blue" because the value is `false`
- **THEN** one `$feature_flag_called` event is enqueued with `$feature_flag_response` false
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant_key` "control"

#### Scenario: A read of the wrong type emits neither event and reserves nothing
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value "blue", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** an accessor that asks for a boolean value reads "checkout-flow" with caller default false
- **AND** it returns false because the value is a string
- **THEN** no `$feature_flag_called` and no `$experiment_exposure` event is enqueued
- **WHEN** an accessor that asks for a string value then reads "checkout-flow" with caller default "red"
- **THEN** it returns "blue"
- **AND** one `$feature_flag_called` event is enqueued with `$feature_flag_response` "blue"
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant_key` "test"

#### Scenario: The exposure does not depend on a linked experiment
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test" and `has_experiment` false
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued with `$feature_flag_variant_key` "test"

