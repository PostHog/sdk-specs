## ADDED Requirements

### Requirement: Values the record did not supply are reported as config version 1

A `$feature_flag_called` event SHALL carry config version 2 attribution (`$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`) only when the value the read reports came from the flag's config version 2 record. When the SDK has a config version 2 record for the flag but that record did not supply the value the read reports, the SDK SHALL send the event as it sends one for a config version 1 flag:

- the event keeps `$feature_flag_reason` where the SDK sends it for a config version 1 flag;
- the event carries no config version 2 attribution;
- the tracker uses the config version 1 dedupe key, without the components that "Config version 2 dedupe key" adds;
- the read SHALL NOT emit `$experiment_exposure`, and SHALL NOT consult or add an exposure key (see `experiment-exposure`).

The record did not supply the value in each of these cases:

- a bootstrapped value from `bootstrap.featureFlags`;
- a client-side override;
- a caller-supplied match value: a payload read that takes a match value (`matchValue` or `match_value`) reports the caller's value, not the record's;
- a stale cached value: a server SDK that falls back to a cache of earlier results reports the cached value when its flags request fails, or when a record arrives but the SDK cannot write it to that cache. The value is the cache's, not the current record's.

When an SDK keeps the loaded record itself, for example a client SDK that keeps its last loaded flags after a failed reload, a read that reports that record's value reads the record, and the record's attribution applies as usual.

A `failed` record supplies no value. When no other value takes its place and the read reports the missing response sentinel, the record's attribution still applies as usual: the event keeps the config version and reason code (see "Failed direct getter evaluations report evaluation_failed").

Pairing a caller's value or a stale value with the record's rule and variant would attribute an exposure to the wrong arm. Without `$feature_flag_config_version`, the event is treated like any config version 1 flag call.

#### Scenario: A payload read with a caller-supplied match value is reported as config version 1
- **GIVEN** a server SDK whose payload read accepts a match value and an option to send flag events
- **AND** remote evaluation for distinct id "user-123" returns "checkout-flow" as a complete config version 2 experiment split with value "annual", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** the payload of "checkout-flow" is read for "user-123" with match value "annual" and flag events turned on
- **THEN** one `$feature_flag_called` event is enqueued with `$feature_flag_response` "annual"
- **AND** it has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

#### Scenario: A later read of the record is not suppressed by the config version 1 key
- **GIVEN** a payload read of "checkout-flow" for distinct id "user-123" with match value "annual" emitted `$feature_flag_called` without config version 2 attribution
- **AND** the record for "checkout-flow" is still a complete config version 2 experiment split with value "annual" and variant key "test"
- **WHEN** "checkout-flow" is read for "user-123" with a value read
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_config_version` 2 and `$feature_flag_variant_key` "test"
- **AND** one `$experiment_exposure` event is enqueued with `$feature_flag_variant_key` "test"

#### Scenario: A stale cached value is not attributed to the record that arrived
- **GIVEN** a server SDK with a cache of earlier results that holds the value "annual" for "checkout-flow" and distinct id "user-123"
- **AND** remote evaluation for "user-123" returns "checkout-flow" as a complete config version 2 experiment split with value "annual" and variant key "test"
- **AND** the SDK cannot write that result to its cache, so the read falls back to the cached value
- **WHEN** a read of "checkout-flow" for "user-123" emits `$feature_flag_called`
- **THEN** the read returns "annual"
- **AND** the event has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

#### Scenario: A stale cached value after a failed flags request carries no attribution
- **GIVEN** a server SDK with a cache of earlier results that holds the value "annual" for "checkout-flow" and distinct id "user-123"
- **AND** the flags request for "user-123" fails
- **WHEN** a read of "checkout-flow" for "user-123" emits `$feature_flag_called`
- **THEN** the read returns "annual"
- **AND** the event has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

## MODIFIED Requirements

### Requirement: Config version 2 attribution on `$feature_flag_called`

When the evaluation details that supplied a read's value come from a config version 2 record that the SDK read without a parse error, the `$feature_flag_called` event SHALL carry these properties:

| Property | Source | Presence |
| --- | --- | --- |
| `$feature_flag_config_version` | `metadata.config_version`, the number `2` | always |
| `$feature_flag_reason_code` | `reason.code` | whenever the record has a reason code |
| `$feature_flag_rule_id` | `metadata.rule_id` | by the table below |
| `$feature_flag_rule_type` | `metadata.rule_type` | by the table below |
| `$feature_flag_variant_key` | `metadata.variant_key` | by the table below |

`$feature_flag_config_version` is the flag's config version. It is distinct from `$feature_flag_version`, the version of the flag's row. `$feature_flag_reason_code` is the machine-readable reason code, and it replaces `$feature_flag_reason`, the human-readable description of the reason: a config version 2 event SHALL NOT carry `$feature_flag_reason`. Config version 1 events keep `$feature_flag_reason` where the SDK sends it today.

The rule fields depend on the reason code:

| Reason code | `$feature_flag_rule_id` and `$feature_flag_rule_type` | `$feature_flag_variant_key` |
| --- | --- | --- |
| `experiment_split` with rule type `experiment`, a rule ID and a variant key | sent | sent |
| `experiment_split` with any of those three missing (a malformed split, see `experiment-exposure`) | not sent | not sent |
| `targeting_match` with rule type `targeted_release` or `percentage_rollout` and a rule ID | sent | not sent |
| `rollout_miss` with rule type `percentage_rollout` or `experiment` and a rule ID | sent | not sent |
| `experiment_paused` or `holdout` with rule type `experiment` and a rule ID | sent | not sent |
| `targeting_match`, `rollout_miss`, `experiment_paused` or `holdout` with no rule ID, no rule type, or a rule type the row above does not allow (for example `targeting_match` with rule type `experiment`) | not sent | not sent |
| `no_rule_match`, `missing_group_key`, `flag_disabled`, `dependency_error`, `error`, any `failed` record, any other reason code, and a record with no reason code | not sent | not sent |

In this table a rule ID counts as present only when it is a string in the hyphenated 8-4-4-4-12 hexadecimal UUID form, the form the event schemas require. A rule ID in any other form counts as missing, so its event omits the rule pair. The SDK SHALL take these values only from the record that supplied the value. It SHALL NOT send a field that the table marks "not sent", even when the record carries it.

A config version 2 record whose reason code is missing or is not one this table names (for example a code a newer server adds) is still a config version 2 result. Its `$feature_flag_called` event SHALL carry `$feature_flag_config_version` 2 and, when the record has a reason code, that code unchanged in `$feature_flag_reason_code`. It SHALL carry no `$feature_flag_rule_id`, `$feature_flag_rule_type` or `$feature_flag_variant_key`, and the read SHALL NOT emit `$experiment_exposure`. The SDK SHALL NOT map the code to another code. Contract 9.0.0 ([posthog-sdk-test-harness#101](https://github.com/PostHog/posthog-sdk-test-harness/pull/101)) accepts these events.

`$feature_flag_rule_id` and `$feature_flag_rule_type` SHALL be sent together or not at all. A record whose rule fields do not form one of the pairs above is invalid producer output: its event keeps `$feature_flag_config_version` and `$feature_flag_reason_code`, omits both rule fields and `$feature_flag_variant_key`, and the value the read returns does not change. The SDK SHALL NOT fill in a missing rule field from the value, the flag key, another flag's record or an earlier result. A rule ID without its rule type, or a pair that names the wrong kind of rule, would look like real attribution in flag analytics; dropping it leaves the reason code to show the gap.

A config version 2 `$feature_flag_called` event SHALL NOT carry `$feature_flag_experiment_id`, a holdout ID, `$feature_flag_forced_variant`, or an assignment seed anywhere in the event.

When a config version 2 record supplies the value, `$feature_flag_response` SHALL be the legacy rendering of the record's value on every read path, including typed reads: `true` or `false` for a boolean, the string for a string, `false` for `null`, and `true` for a number or an object. It SHALL NOT be a caller default. This holds until an event schema for number and object values is decided.

The SDK SHALL NOT add any of these properties for a config version 1 record, a record from a server that does not send typed values, a missing flag, or a value that the record did not supply: a bootstrapped value, a client-side override, a caller-supplied match value or a stale cached value (see "Values the record did not supply are reported as config version 1"). Those events do not change.

#### Scenario: An experiment split carries the full rule tuple
- **GIVEN** the record for "checkout-flow" has value "blue", reason code `experiment_split`, and metadata config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event properties include:
  | property                     | value                                |
  | $feature_flag                | checkout-flow                        |
  | $feature_flag_response       | blue                                 |
  | $feature_flag_config_version | 2                                    |
  | $feature_flag_reason_code    | experiment_split                     |
  | $feature_flag_rule_id        | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
  | $feature_flag_rule_type      | experiment                           |
  | $feature_flag_variant_key    | test                                 |
- **AND** it has no `$feature_flag_reason`

#### Scenario: A config version 2 event carries the reason code, not the description
- **GIVEN** the record for "beta-ui" has value true, reason code `targeting_match` with description "Matched rule 1", config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "targeting_match"
- **AND** it has no `$feature_flag_reason`

#### Scenario: A holdout names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `holdout`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "holdout", `$feature_flag_rule_type` "experiment" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant_key`

#### Scenario: A terminal rollout exclusion names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `rollout_miss`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "rollout_miss" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant_key`

#### Scenario: A paused experiment names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `experiment_paused`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "experiment_paused" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant_key`

#### Scenario: Targeted and percentage matches have no variant
- **GIVEN** the record for "beta-ui" has value true, reason code `targeting_match`, config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **AND** the record for "new-nav" has value true, reason code `targeting_match`, config version 2, rule type `percentage_rollout` and rule id "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45"
- **WHEN** reads of "beta-ui" and "new-nav" emit `$feature_flag_called`
- **THEN** each event has `$feature_flag_reason_code` "targeting_match" and its record's rule type and rule id
- **AND** neither event has `$feature_flag_variant_key`

#### Scenario: A no-rule match carries no rule identity
- **GIVEN** the record for "beta-ui" has value false, reason code `no_rule_match` and config version 2
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "no_rule_match"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`

#### Scenario: A failed record carries no rule identity
- **GIVEN** the record for "beta-ui" has `failed` true, reason code `dependency_error` and config version 2
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "dependency_error"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`

#### Scenario: An unknown reason code is sent unchanged without rule identity
- **GIVEN** the record for "beta-ui" has value true, reason code "future_reason", config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the read returns true
- **AND** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "future_reason"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

#### Scenario: A record without a reason code keeps its config version
- **GIVEN** the record for "beta-ui" has value true, config version 2 and no reason
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2
- **AND** it has none of `$feature_flag_reason_code`, `$feature_flag_reason`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

#### Scenario: A rule ID without a rule type is not sent
- **GIVEN** the record for "beta-ui" has value true, reason code `targeting_match`, config version 2 and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96", and no rule type
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the read returns true
- **AND** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "targeting_match"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`

#### Scenario: A targeting match that names an experiment rule is not attributed
- **GIVEN** the record for "checkout-flow" has value true, reason code `targeting_match`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "targeting_match"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is enqueued

#### Scenario: A forbidden field in the record is not sent
- **GIVEN** the record for "checkout-flow" has reason code `holdout`, config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and also a variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant_key`

#### Scenario: A number value is reported with its legacy rendering
- **GIVEN** the record for "search-ranking" has the number value 25, reason code `targeting_match`, config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **WHEN** a read of "search-ranking" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_response` true

#### Scenario: Config version 1 events do not change
- **GIVEN** the record for "legacy-layout" has value "compact", reason code `condition_match` with description "Matched condition set 1", config version 1 and variant key "compact"
- **WHEN** a read of "legacy-layout" emits `$feature_flag_called`
- **THEN** the event has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`
- **AND** in an SDK that sends `$feature_flag_reason`, the event has `$feature_flag_reason` "Matched condition set 1"

