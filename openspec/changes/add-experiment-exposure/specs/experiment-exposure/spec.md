## ADDED Requirements

### Requirement: Experiment exposure trigger

Every flag read that emits `$feature_flag_called` SHALL keep emitting it as the existing requirements define. The same read SHALL also emit one `$experiment_exposure` event when the evaluation details that supplied the read's value meet all of these conditions:

- the record was read without a parse error and is not `failed`;
- `metadata.config_version` is 2;
- `reason.code` is `experiment_split`;
- `metadata.rule_type` is `experiment`;
- `metadata.rule_id` is present;
- `metadata.variant_key` is present;
- the value came from the flags service or from local evaluation, not from a bootstrapped value or a client-side override.

"Present" means the member exists and is not `null`. This applies to every read path that emits `$feature_flag_called`: client getters such as `getFeatureFlag`, `isFeatureEnabled` and `getFeatureFlagResult`, server single-flag getters, snapshot enablement and value reads (see `evaluate-flags`), and typed value or details accessors where the SDK has them. Whether a read emits `$feature_flag_called` at all is decided as the existing requirements and "Feature flag event decision covers the exposure" define.

The trigger SHALL NOT depend on whether an experiment links to the rule. `metadata.has_experiment`, and any experiment the SDK knows about, are not inputs.

No other outcome SHALL emit `$experiment_exposure`: not a targeting match, a percentage rollout match, a terminal rollout miss (including an experiment rule's rollout exclusion), a holdout, a paused experiment, a no-rule match or flag default, a missing flag, a failed or unreadable record, a bootstrapped value, a client-side override, a config version 1 record, or a record from a server that does not send typed values (which reads as config version 1).

The decision SHALL use the evaluation details that supplied the value, not the value the read returned. A read that returned a caller-supplied default instead of the flag's value, because the value is `null` or is `false` read as another type, SHALL still emit the exposure when the details meet the conditions. An arm whose value is `false` is still an assignment.

A typed read that returned the caller default because the value has another type than the read asks for (a type mismatch) SHALL emit neither `$feature_flag_called` nor `$experiment_exposure`, and SHALL NOT consult or update either dedupe namespace, so the next read of the right type emits both. The SDK logs the mismatch instead, as the typed accessors define.

#### Scenario: An experiment split emits both events
- **GIVEN** the record for "checkout-flow" has value true, `failed` false, reason code `experiment_split`, and metadata config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** exactly one `$feature_flag_called` event is enqueued for "checkout-flow"
- **AND** exactly one `$experiment_exposure` event is enqueued for "checkout-flow" with `$feature_flag_variant` "test" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"

#### Scenario: An arm whose value is false is still exposed
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "control" and value false
- **WHEN** an enablement read of "checkout-flow" returns false and emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued with `$feature_flag_variant` "control" and `$feature_flag_response` false

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

#### Scenario: A read that returns its caller default for a false arm still reports the assignment
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** an accessor that asks for a string value reads "checkout-flow" with caller default "blue"
- **AND** it returns "blue" because the value is `false`
- **THEN** one `$feature_flag_called` event is enqueued with `$feature_flag_response` false
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant` "control"

#### Scenario: A read of the wrong type emits neither event and reserves nothing
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value "blue", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** an accessor that asks for a boolean value reads "checkout-flow" with caller default false
- **AND** it returns false because the value is a string
- **THEN** no `$feature_flag_called` and no `$experiment_exposure` event is enqueued
- **WHEN** an accessor that asks for a string value then reads "checkout-flow" with caller default "red"
- **THEN** it returns "blue"
- **AND** one `$feature_flag_called` event is enqueued with `$feature_flag_response` "blue"
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant` "test"

#### Scenario: The exposure does not depend on a linked experiment
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test" and `has_experiment` false
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued with `$feature_flag_variant` "test"

### Requirement: Malformed experiment splits fail closed

The SDK SHALL treat a record with reason code `experiment_split` whose rule type is not `experiment`, or that has no rule ID or no variant key, as a malformed split. For a malformed split the SDK:

- SHALL NOT emit `$experiment_exposure`;
- SHALL NOT change the value the read returns because of the missing fields;
- SHALL emit the `$feature_flag_called` event the read would emit for a complete record, keeping `$feature_flag_config_version` 2 and `$feature_flag_reason_code` `experiment_split`, and SHALL omit the whole rule tuple: `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`. It SHALL NOT send part of the tuple;
- SHALL NOT fill in a missing field from the value, the flag key, `has_experiment`, a linked experiment, another flag's record, or a result cached from an earlier evaluation.

The diagnostic event keeps config version 2 so that ingestion does not derive an exposure from it, and keeps the reason code so the gap stays visible.

#### Scenario: A split without a variant key emits a diagnostic call only
- **GIVEN** the record for "checkout-flow" has value "blue", reason code `experiment_split`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13", and no variant key
- **WHEN** a value read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the read returns "blue"
- **AND** no `$experiment_exposure` event is enqueued
- **AND** the `$feature_flag_called` event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "experiment_split"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`

#### Scenario: A split with another rule type emits no exposure
- **GIVEN** the record for "checkout-flow" has reason code `experiment_split`, config version 2, rule type `percentage_rollout`, rule id "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45" and variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued
- **AND** the `$feature_flag_called` event has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`

#### Scenario: The SDK does not guess a missing rule ID from an earlier result
- **GIVEN** an earlier read of "checkout-flow" reported a complete split with rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **AND** a flags reload replaces the record with a split for variant key "test" that has no rule id
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued for that read
- **AND** its `$feature_flag_called` event has no `$feature_flag_rule_id`

### Requirement: Experiment exposure properties

Each `$experiment_exposure` event SHALL carry these properties:

| Property | Value |
| --- | --- |
| `$feature_flag` | The flag key. |
| `$feature_flag_response` | The legacy rendering of the record's value, the same as on the paired `$feature_flag_called` event: `true` or `false` for a boolean, the string for a string, `false` for `null`, and `true` for a number or an object. |
| `$feature_flag_variant` | `metadata.variant_key` |
| `$feature_flag_rule_id` | `metadata.rule_id` |
| `locally_evaluated` | `true` when local evaluation produced the details, otherwise `false`. Client SDKs, whose values come from the flags service, send `false`. |

`$feature_flag_response` on the exposure is diagnostic only. The arm is `$feature_flag_variant`, which separates arms whose values are equal. The rule ID identifies the experiment rule, and its presence marks the exposure as sent by the SDK.

The exposure SHALL NOT carry `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_type` or `$experiment_exposure_source`. The SDK sends the exposure only for a config version 2 experiment split, so their values would be constants. The paired `$feature_flag_called` event keeps them (see `feature-flag-called-tracker`).

The SDK SHALL also include each of these that is available for the read, with the value it puts on the paired `$feature_flag_called` event:

- `$feature_flag_id` and `$feature_flag_version` from the record's metadata;
- `$feature_flag_request_id` and `$feature_flag_evaluated_at`;
- the time the flag definitions were loaded, for locally evaluated results, under the name the SDK uses on `$feature_flag_called` (for example `$feature_flag_definitions_loaded_at`);
- the library identity (`$lib`, `$lib_version`);
- `$groups`.

The SDK SHALL capture the exposure for the same capture identity as the paired `$feature_flag_called` event: the same distinct ID, group context, person-processing setting and session. The exposure SHALL be a separate capture with its own event UUID.

The exposure MAY also carry `$feature_flag_payload`, `$feature/<key>` and the other properties the SDK's normal capture path adds, for transport compatibility. It SHALL NOT carry `$feature_flag_experiment_id`, a holdout ID, `$feature_flag_forced_variant`, or an assignment seed anywhere in the event, even when the record carries such a field. Minimal-event mode (see `feature-flag-called-tracker`) SHALL NOT apply to `$experiment_exposure`.

#### Scenario: Exposure properties of a remotely evaluated split
- **GIVEN** a server SDK evaluates "checkout-flow" remotely for distinct id "user-123"
- **AND** the record has value true, reason code `experiment_split`, and metadata id 412, version 9, config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **AND** the response has request id "7c0e5d1a-3b2f-4e6d-8a9c-0f1e2d3c4b5a"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the `$experiment_exposure` event has distinct id "user-123" and these properties:
  | property                 | value                                |
  | $feature_flag            | checkout-flow                        |
  | $feature_flag_response   | true                                 |
  | $feature_flag_variant    | test                                 |
  | $feature_flag_rule_id    | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
  | locally_evaluated        | false                                |
  | $feature_flag_id         | 412                                  |
  | $feature_flag_version    | 9                                    |
  | $feature_flag_request_id | 7c0e5d1a-3b2f-4e6d-8a9c-0f1e2d3c4b5a |
- **AND** it has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_type` and `$experiment_exposure_source`
- **AND** its event UUID differs from the UUID of the paired `$feature_flag_called` event

#### Scenario: A number-valued arm is rendered as true
- **GIVEN** the record for "search-ranking" is a complete config version 2 experiment split with variant key "boosted" and the number value 25
- **WHEN** a read of "search-ranking" emits `$feature_flag_called`
- **THEN** the `$experiment_exposure` event has `$feature_flag_response` true and `$feature_flag_variant` "boosted"

#### Scenario: An unexpected experiment ID is not sent
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test" that also carries `metadata.experiment_id` 301
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued
- **AND** neither event has a `$feature_flag_experiment_id` property

#### Scenario: Group context is carried on the exposure
- **GIVEN** a server SDK evaluates the group flag "checkout-flow" for distinct id "user-123" with group "company" "company-123"
- **AND** the record is a complete config version 2 experiment split with variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the `$experiment_exposure` event has `$groups` with "company" "company-123"

### Requirement: Experiment exposure dedupe

The SDK SHALL dedupe `$experiment_exposure` in its own namespace, separate from the `$feature_flag_called` tracker entries. The key SHALL be:

- the distinct ID, in the string form the event carries;
- the canonical group context, normalized as the flag-called tracker normalizes it;
- the flag key;
- the config version;
- the rule ID;
- the variant key.

Nothing else SHALL be part of the key. In particular the value, its legacy rendering, the request ID, the evaluation time, the local or remote source and the flag's row version are left out. A remote result that repeats an earlier local assignment is therefore not a second exposure, while arms with equal values stay separate through their variant keys.

A read SHALL emit the exposure only when its key is not yet in the namespace, and SHALL then add the key. Check and add SHOULD be atomic, so concurrent reads do not emit the same exposure twice.

An SDK that stores both events' dedupe entries in one cache SHALL make the event name part of each key, or check and mark both entries in one atomic step, so an entry for `$feature_flag_called` never suppresses its exposure.

Bootstrapped and overridden values SHALL NOT add an exposure key.

The namespace SHALL be bounded and evicted like the flag-called tracker: when it reaches capacity it evicts old entries incrementally and is never cleared wholesale for capacity. It SHALL be cleared at the same identity-reset and close or shutdown boundaries as the tracker. An SDK MAY keep it across a flags reload even when it clears the flag-called tracker, because its key already identifies the assignment. An SDK that persists the flag-called tracker MAY persist the namespace in the same way.

#### Scenario: A repeated read emits one exposure
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** "checkout-flow" is read three times for distinct id "user-123"
- **THEN** exactly one `$feature_flag_called` and exactly one `$experiment_exposure` event are enqueued for "checkout-flow"

#### Scenario: A remote result after the same local assignment is not a second exposure
- **GIVEN** a server SDK evaluated "checkout-flow" locally for distinct id "user-123" and emitted an exposure for rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test" with `locally_evaluated` true
- **WHEN** a later read for "user-123" is answered by remote evaluation with the same rule id and variant key, a new request id and a new evaluation time
- **THEN** no second `$experiment_exposure` event is enqueued for "checkout-flow" and "user-123"

#### Scenario: A/A arms with equal values stay separate
- **GIVEN** the flag "pricing-page" has an experiment rule whose arms "control" and "test" both return true
- **AND** a read for distinct id "user-123" emitted an exposure for variant key "control"
- **WHEN** a later evaluation for "user-123" assigns variant key "test" in the same rule, still with value true
- **AND** "pricing-page" is read again
- **THEN** a second `$experiment_exposure` event is enqueued for "pricing-page" with `$feature_flag_variant` "test"

#### Scenario: A new experiment rule is a new exposure
- **GIVEN** a read for distinct id "user-123" emitted an exposure for "checkout-flow" with rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** the flag's next evaluation for "user-123" is a split by another experiment rule with rule id "8e2d4a61-0b5c-4f3a-a7d9-1c6e2b9f4d70" and variant key "test"
- **AND** "checkout-flow" is read again
- **THEN** a second `$experiment_exposure` event is enqueued with `$feature_flag_rule_id` "8e2d4a61-0b5c-4f3a-a7d9-1c6e2b9f4d70"

#### Scenario: Another group is a new exposure
- **GIVEN** a server SDK emitted an exposure for the group flag "checkout-flow", distinct id "user-123" and group "company" "company-123"
- **WHEN** "checkout-flow" is read for "user-123" with group "company" "company-456" and the record is a split with the same rule id and variant key
- **THEN** a second `$experiment_exposure` event is enqueued

#### Scenario: The flag-called entry does not suppress its exposure
- **GIVEN** an SDK stores flag-called and exposure dedupe entries in one cache
- **AND** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test"
- **WHEN** a read of "checkout-flow" marks its `$feature_flag_called` entry before it checks the exposure entry
- **THEN** both `$feature_flag_called` and `$experiment_exposure` are enqueued for that read

### Requirement: Feature flag event decision covers the exposure

The feature flag event decision that governs `$feature_flag_called` for a read SHALL govern `$experiment_exposure` for that read too. The decision is the per-read or per-call option when the caller supplies one, otherwise the SDK's client-level feature flag event default when it has one, otherwise `true`, as `evaluate-flags` ("Snapshot feature flag event control") and `get-feature-flag-result` ("Per-call feature flag event option name") define it. The SDK SHALL NOT add a separate option for the exposure.

When the decision is `false`, the read SHALL emit neither event and SHALL NOT consult or update either dedupe namespace, so a later read whose decision is `true` still emits both. The decision SHALL NOT change the returned value.

A read that does not emit `$feature_flag_called` by design, such as a payload-only read, a key enumeration or an in-memory filter, SHALL NOT emit `$experiment_exposure`.

#### Scenario: A client-level opt-out suppresses both events
- **GIVEN** the SDK's client-level feature flag event default is disabled
- **AND** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test"
- **WHEN** "checkout-flow" is read without a per-read option
- **THEN** no `$feature_flag_called` and no `$experiment_exposure` event is enqueued

#### Scenario: A per-read opt-out suppresses both events and reserves nothing
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test"
- **WHEN** "checkout-flow" is read with the per-read feature flag event option `false`
- **AND** "checkout-flow" is read again without the option
- **THEN** exactly one `$feature_flag_called` and exactly one `$experiment_exposure` event are enqueued, both from the second read

#### Scenario: A payload-only read emits no exposure
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with variant key "test"
- **WHEN** only the payload of "checkout-flow" is read
- **THEN** no `$feature_flag_called` and no `$experiment_exposure` event is enqueued

### Requirement: Bootstrapped and overridden values emit no exposure

A value served from `bootstrap.featureFlags`, or set by a client-side override, has no reason or rule metadata. A read that returns such a value SHALL NOT emit `$experiment_exposure` and SHALL NOT add an exposure dedupe key. Its `$feature_flag_called` event carries no config version 2 attribution (see `feature-flag-called-tracker`). A client-side override SHALL suppress the exposure even when the record it replaces is a complete experiment split.

Once a flags response replaces a bootstrapped value (see `bootstrap`), the next read SHALL apply the trigger to the record from that response.

#### Scenario: A bootstrapped value emits no exposure and reserves nothing
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "checkout-flow": true }`
- **WHEN** "checkout-flow" is read before any flags response
- **THEN** one `$feature_flag_called` event is enqueued without `$feature_flag_config_version`
- **AND** no `$experiment_exposure` event is enqueued
- **WHEN** a flags response arrives whose record for "checkout-flow" is a complete config version 2 experiment split with value true and variant key "test"
- **AND** "checkout-flow" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_variant` "test"
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant` "test"

#### Scenario: An override suppresses the exposure
- **GIVEN** the loaded record for "checkout-flow" is a complete config version 2 experiment split with variant key "test"
- **AND** a client-side override sets "checkout-flow" to true
- **WHEN** "checkout-flow" is read
- **THEN** no `$experiment_exposure` event is enqueued
- **AND** the `$feature_flag_called` event carries no `$feature_flag_rule_id` and no `$feature_flag_variant`

### Requirement: Locally evaluated results

A server SDK that evaluates config version 2 flags locally SHALL produce the same reason code, rule ID, rule type and variant key that the flags service would produce for the same inputs, and SHALL apply the trigger, the properties and the dedupe of this capability to those details, with `locally_evaluated` true. A server SDK that does not evaluate config version 2 flags locally gets them from remote evaluation, and its exposures carry `locally_evaluated` false.

Config version 1 flags SHALL NOT get a direct SDK exposure, whether they are evaluated locally or remotely. Their exposures stay with the ingestion-derived path.

#### Scenario: A locally evaluated split is exposed
- **GIVEN** a server SDK with config version 2 local evaluation resolves "checkout-flow" for distinct id "user-123" to an experiment split with rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** one `$experiment_exposure` event is enqueued with `locally_evaluated` true and `$feature_flag_variant` "test"

#### Scenario: A locally evaluated config version 1 flag gets no SDK exposure
- **GIVEN** a server SDK evaluates the config version 1 multivariate flag "legacy-layout" locally to variant "compact"
- **WHEN** a read of "legacy-layout" emits `$feature_flag_called`
- **THEN** no `$experiment_exposure` event is enqueued

### Requirement: Exposure capture is built in one best-effort step

The SDK SHALL build a read's `$feature_flag_called` and `$experiment_exposure` events, and their dedupe keys, in one step. Its inputs SHALL be:

- the flag key;
- the evaluation details that supplied the value: the value, `failed`, `reason` and `metadata`;
- the read's context: whether the value was bootstrapped or overridden, whether local evaluation produced the details (and the definitions-loaded time when it did), the request ID, evaluation time and any error the read reports, the capture context (distinct ID and groups), the SDK's event settings such as the minimal-event gate, and the read's feature flag event decision.

The step SHALL NOT read the value the read returned, flag definitions, other flags' records, or results cached from other evaluations. A wrapper that holds the same evaluation details and context, such as an OpenFeature provider hook, can then reuse the step and produce the same events.

Capturing both events SHALL be best-effort. It SHALL NOT change the value a read returns, SHALL NOT make a read throw or reject, and SHALL NOT cause flag evaluation, network I/O or a flags reload. When capture fails, including when application code that runs during capture throws, the SDK SHALL log the failure and return the read's value.

#### Scenario: A failing exposure capture does not break the read
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value true and variant key "test"
- **AND** application code that runs when the SDK captures `$experiment_exposure` throws an exception
- **WHEN** "checkout-flow" is read
- **THEN** the read returns true without throwing

#### Scenario: Missing details are not fetched
- **GIVEN** a client SDK restored flag state for "checkout-flow" that an older SDK version persisted without typed values or rule metadata
- **WHEN** "checkout-flow" is read
- **THEN** no `$experiment_exposure` event is enqueued
- **AND** the read makes no flags request
