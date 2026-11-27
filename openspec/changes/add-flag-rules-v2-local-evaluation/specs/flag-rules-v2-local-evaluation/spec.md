## ADDED Requirements

### Requirement: Requesting the version 2 definitions feed

A server SDK SHALL request local-evaluation definitions with the query parameter `v=2` only when it meets every requirement of this capability, reads `/flags?v=4` records, sends the config version 2 attribution on `$feature_flag_called` (`feature-flag-called-tracker`), and sends `$experiment_exposure` (`experiment-exposure`). Such an SDK SHALL send exactly one `v` parameter, with the value `2`, on every definitions request: the first load, each poll, a manual reload, and a conditional request that carries an ETag. It SHALL keep every other parameter and header of the request as it is, and SHALL NOT offer an option that sends another value or none. An SDK that does not meet these requirements SHALL NOT send a `v` parameter on a definitions request.

The flags service answers exactly `v=2` with the version 2 feed. It answers every other value, a repeated `v` and no `v` with the legacy feed, which leaves config version 2 flags out. A server that does not know the parameter ignores it and answers with the legacy feed. The ETag of a `v=2` response is the validator for the next `v=2` request.

Why: an SDK without a config version 2 evaluator reads a config version 2 document as a config version 1 flag with no conditions. It returns `false` as a local result, with no remote fallback. Leaving config version 2 flags out of the legacy feed is what protects those SDKs, so only an SDK that can evaluate the flags may ask for them.

#### Scenario: Every definitions request asks for the version 2 feed (@server)
- **GIVEN** a server SDK with this capability and local evaluation enabled
- **WHEN** it loads definitions, polls them again, and reloads them manually
- **THEN** each definitions request carries exactly one `v` parameter, equal to `2`
- **AND** a request that follows a `200` response with an ETag sends that ETag, as before

#### Scenario: An SDK without the config version 2 evaluator does not ask for the feed (@server)
- **GIVEN** a server SDK that does not evaluate config version 2 flags locally
- **WHEN** it loads definitions
- **THEN** the definitions request carries no `v` parameter

### Requirement: Loading the version 2 feed

The SDK SHALL read the version 2 feed as it reads the legacy feed: `flags`, `group_type_mapping`, `cohorts`, and the optional `minimal_flag_called_events` and `property_matching_version`. The `flags` list holds config version 1 entries, exactly as the legacy feed carries them, and config version 2 entries, inactive ones included. For a project without config version 2 flags, the flags service answers `v=2` with the legacy body and its ETag. The SDK SHALL load that body as a complete version 2 feed, and its results SHALL NOT change.

The SDK SHALL load every entry it can read. It SHALL NOT reject the feed, or another entry, because one entry is unsupported. It SHALL ignore top-level fields, and entry fields outside `filters`, that it does not know.

#### Scenario: A legacy body is a complete version 2 feed (@server)
- **GIVEN** a project has only config version 1 flags, and the flags service answers `v=2` with the legacy body
- **WHEN** the SDK loads the body and evaluates the config version 1 flag "legacy-banner"
- **THEN** the result is the result the SDK returned before it requested `v=2`
- **AND** no remote evaluation request is sent

#### Scenario: Config version 1 and 2 entries load side by side (@server)
- **GIVEN** the feed holds the config version 1 flag "legacy-banner" and the config version 2 flag "layout-preview"
- **WHEN** both flags are read locally
- **THEN** the config version 1 evaluator decides "legacy-banner" and the config version 2 evaluator decides "layout-preview"
- **AND** no remote evaluation request is sent

#### Scenario: An unknown entry field outside filters is ignored (@server)
- **GIVEN** a config version 2 entry carries an entry field that this SDK does not know, outside `filters`
- **WHEN** the feed is loaded and the flag is read
- **THEN** the flag is evaluated as if the field were absent

### Requirement: Closed parsing of config version 2 documents

The SDK SHALL read each config version 2 `filters` document with a closed parser. It SHOULD parse a document once, when it loads the definitions, and evaluate the parsed form on each read. The parser SHALL accept exactly the documents that the public rules v2 contract accepts: `contracts/feature_flag_rules_v2/schemas/config.schema.json` in posthog-sdk-test-harness, its literal registry and its semantic constraints. It SHALL mark every other document unsupported, including a document with an unknown return type, rule type, property type, operator, `on_rollout_miss` policy, assignment target or assignment algorithm; a field that a closed object does not define; a missing required field; or a value of the wrong JSON type or outside its range. The parser SHALL ignore the presentation fields that the contract allows and evaluators do not read: a rule's `description` and `metadata`, and a predicate's `label`.

Until the contract defines how to evaluate them, the SDK SHALL also mark unsupported a document that aggregates by group (`aggregation_group_type_index`) or has a predicate of type `group`, `cohort` or `flag`. Such a flag falls back to the flags service.

An unsupported document makes the whole flag unsupported. The SDK SHALL NOT evaluate any rule of it, including a rule that comes before the unsupported part. Other entries of the feed are not affected.

Why: a document written for a newer contract can change the meaning of the rules the parser does recognise. A parser that evaluates what it recognises and skips the rest returns a value that the flags service would not.

#### Scenario: An unknown rule type in a later rule makes the whole flag unsupported (@server)
- **GIVEN** the config version 2 flag "future-rule-type" has a first rule that targets everyone with the value `true`, and a second rule of rule type "scheduled_release"
- **WHEN** "future-rule-type" is read locally for distinct id "person-example"
- **THEN** local evaluation is inconclusive with the reason `unsupported_definition`
- **AND** the first rule's value is not returned as a local result

#### Scenario: An unknown field in a later rule makes the whole flag unsupported (@server)
- **GIVEN** the config version 2 flag "future-rule-field" has a first rule that targets everyone with the value "compact", and a second rule that carries the field "schedule"
- **WHEN** "future-rule-field" is read locally for distinct id "person-example"
- **THEN** local evaluation is inconclusive with the reason `unsupported_definition`

#### Scenario Outline: Group, cohort and flag targeting are unsupported for now (@server)
- **GIVEN** a config version 2 flag whose document has <construct>
- **WHEN** the flag is read locally
- **THEN** local evaluation is inconclusive with the reason `unsupported_definition`

  | construct |
  | `aggregation_group_type_index` 0 |
  | a predicate of type `group` |
  | a predicate of type `cohort` |
  | a predicate of type `flag` |

#### Scenario: Open objects do not make a document unsupported (@server)
- **GIVEN** the config version 2 flag "layout-preview" has a rule with a `description`, rule `metadata` `{"display_color": "blue"}` and a predicate `label`
- **WHEN** "layout-preview" is read locally
- **THEN** it is evaluated, and the `description`, `metadata` and `label` do not change the result

### Requirement: Ordered evaluation of config version 2 flags

The SDK SHALL evaluate a parsed config version 2 flag as the public rules v2 contract defines. Its result SHALL equal the expected value, reason code, rule and variant of every case of the contract's evaluation corpora that the contract's local outcome table (`rules/local_outcomes.json`) marks `conclusive`, and it SHALL return no value for every case that the table marks `inconclusive`.

Rules are tried in stored order, and the predicates of a rule are checked in stored order. The first predicate that does not match ends that rule, and evaluation moves on to the next rule. The first predicate that the SDK cannot decide ends the whole evaluation as inconclusive. The SDK SHALL NOT skip a rule it cannot decide to try a later rule, because an earlier rule that matches is terminal.

The SDK SHALL evaluate with these inputs:

- the identifier: the distinct ID, as a string;
- the person properties that the caller supplied, as a partial map. A key that the caller did not supply is unknown, not absent, so no predicate on it can be decided, including `is_not_set`. In an SDK that accepts the known-absence input of `local-feature-flag-evaluator`, a key that the caller lists as known absent cannot be decided either, and the SDK SHALL NOT read a value that the caller also supplied for it. The remote fallback carries the listing, as "Remote fallback carries known-absent keys" in `local-feature-flag-evaluator` defines;
- explicit exact matching when the definitions snapshot's `property_matching_version` is `2`, as "Definition snapshots retain the property matching version" in `flag-definition-loader` defines;
- UTC as the timezone (see "Dates are read in UTC").

A predicate also cannot be decided when the supplied value is one that the contract's cases mark `invalid_property`, such as `null` for `gt`, or when the SDK cannot reproduce how the flags service reads a value that the contract does not pin, for example a date format that the contract does not list. The SDK SHALL NOT treat such a predicate as a match or as a miss. A supplied value whose result the contract pins keeps that result: a string that is not a date, for a date operator, or not a version, for a semantic-version operator, is a miss (`v2_boolean.property.date_bad_subject`, `v2_boolean.property.semver_bad_subject`).

#### Scenario: A rule that matches before a missing property decides the flag (@server)
- **GIVEN** the string flag "example-display-key" has three rules in this order: "plan" is "pro" returns "first"; "color" is "blue" returns "second"; everyone returns "third"
- **WHEN** it is read locally with person properties `{"plan": "pro"}`
- **THEN** the result is "first" with the reason code `targeting_match` and the first rule
- **AND** no remote evaluation request is sent

#### Scenario: A missing property ends the evaluation (@server)
- **GIVEN** the same flag "example-display-key"
- **WHEN** it is read locally with person properties `{"plan": "free"}`
- **THEN** local evaluation is inconclusive with the reason `missing_context`
- **AND** the third rule's value "third" is not returned as a local result

#### Scenario: is_not_set on a key the caller did not supply cannot be decided (@server)
- **GIVEN** the boolean flag "beta-opt-in" has one rule that targets persons whose "opted_out" property `is_not_set`
- **WHEN** it is read locally with person properties `{"plan": "pro"}`
- **THEN** local evaluation is inconclusive with the reason `missing_context`

#### Scenario: A key listed as known absent is not decided locally (@server)
- **GIVEN** the same flag "beta-opt-in", in an SDK that accepts known-absent property keys
- **WHEN** it is read with person properties `{"opted_out": true}` and person property key "opted_out" listed as known absent
- **THEN** local evaluation is inconclusive with the reason `missing_context`
- **AND** the remote fallback request carries `person_property_keys_known_absent` equal to `["opted_out"]`

### Requirement: Local outcomes use the existing fallback paths

Each local outcome of a config version 2 flag SHALL use a path that the SDK already has for config version 1 flags:

| Local outcome | Auto mode | Local-only mode | Unresolved reason |
| --- | --- | --- | --- |
| Conclusive | The local record. No remote evaluation request for this flag. | The local record. | none |
| A predicate cannot be decided: a missing property, a key listed as known absent, or a supplied value that "Ordered evaluation of config version 2 flags" leaves undecided | Remote fallback for this flag | No value: the flag is unresolved | `missing_context` |
| Unsupported document, or an invalid regular expression | Remote fallback for this flag | No value: the flag is unresolved | `unsupported_definition` |
| Inactive flag | The `flag_disabled` record of "Inactive config version 2 flags" | The same record | none |

The SDK SHALL NOT turn an inconclusive or unsupported outcome into `false`, the flag's `default_value`, an empty string, an empty object, or the value of a later rule. A failed remote fallback follows the existing rules for a failed remote evaluation, and the SDK SHALL NOT replace it with a local value.

A single read falls back for its own flag. A bulk read and an evaluated snapshot use the single fallback request that `evaluate-flags` and `get-feature-flags` already define, and keep every locally resolved record. "Snapshot unresolved flag reporting" in `evaluate-flags` applies unchanged. The reason reported is the cause that ended the evaluation. The document is parsed before any rule is evaluated, so an unsupported document reports `unsupported_definition` whatever the context.

#### Scenario: An unsupported flag falls back on its own in auto mode (@server)
- **GIVEN** the feed holds the supported config version 2 flag "layout-preview" and the unsupported flag "future-rule-type"
- **AND** the flags service returns `false` for "future-rule-type"
- **WHEN** "future-rule-type" is read for distinct id "person-example"
- **THEN** the read returns `false` from the remote response
- **AND** one remote evaluation request is sent
- **WHEN** "layout-preview" is read for distinct id "person-example" with person properties `{"plan": "pro"}`
- **THEN** the read returns `true` with no further remote evaluation request

#### Scenario: In local-only mode an undecided flag has no value (@server)
- **GIVEN** the feed holds the supported flag "layout-preview" and the unsupported flags "future-config-version", "future-rule-type" and "future-rule-field"
- **WHEN** flags are evaluated for distinct id "person-example" with person properties `{"plan": "pro"}` and local-only evaluation enabled
- **THEN** the snapshot has "layout-preview" with the value `true`
- **AND** the snapshot has no value for the three unsupported flags, and reports each as unresolved with the reason `unsupported_definition` where the SDK exposes unresolved flags
- **AND** no remote evaluation request is sent

#### Scenario: A bulk read falls back once and keeps the local records (@server)
- **GIVEN** the feed holds the supported flags "layout-preview" and "checkout-copy" and the unsupported flag "future-rule-type"
- **AND** the flags service returns `false` for "layout-preview" and `false` for "future-rule-type"
- **WHEN** flags are evaluated for distinct id "person-example" with person properties `{"plan": "pro"}`
- **THEN** one remote evaluation request is sent
- **AND** the snapshot has "layout-preview" `true` and "checkout-copy" "short" from local evaluation, and "future-rule-type" `false` from the remote response

#### Scenario: A failed fallback is not turned into a local value (@server)
- **GIVEN** local evaluation of the config version 2 flag "example-display-key" is inconclusive with the reason `missing_context`
- **AND** the remote fallback fails
- **WHEN** the flag is read
- **THEN** the read reports no value, as for a failed remote evaluation of a config version 1 flag
- **AND** it does not return "third", `false` or the flag's default value

### Requirement: Inactive config version 2 flags

For a config version 2 entry with `active: false`, the SDK SHALL return a conclusive result before it reads any rule, whether or not the document is supported: the value `null`, the reason code `flag_disabled`, config version 2, and no rule or variant. The result is never inconclusive, never unresolved, and never falls back. Legacy getters render it as `false` with no payload, the result of an inactive config version 1 flag. A typed read, in an SDK that has typed reads, returns the caller's default.

Why: the flags service leaves an inactive flag out of every response, so a fallback can never return a value for it. An inactive flag is off whatever its rules say.

#### Scenario Outline: An inactive flag is off whatever its rules say (@server)
- **GIVEN** the inactive config version 2 flag "example-display-key" has <document>
- **WHEN** it is read locally for distinct id "person-example" with person properties `{"plan": "pro"}`
- **THEN** the result has the value `null` and the reason code `flag_disabled`, with no rule or variant
- **AND** the legacy getter returns `false` with no payload
- **AND** no remote evaluation request is sent

  | document |
  | a boolean rule that targets everyone with `true`, and the default value `true` |
  | an experiment rule that would assign a variant |
  | a rule that needs the person property "color", which the caller did not supply |
  | a rule of an unknown rule type |

### Requirement: The local record

The SDK SHALL hold a conclusive local result as the record that a `/flags?v=4` response carries for the same result, so that every read path, snapshot and event treats a local record and a remote record alike:

- `value`: the typed value, a boolean, string, number, object or `null`;
- `reason.code`: the reason code;
- `reason.condition_index`: the zero-based index of the rule that ended the evaluation, or `null` when no rule did;
- `metadata.config_version`: `2`;
- `metadata.rule_id` and `metadata.rule_type`: the rule that ended the evaluation, for a reason code that names a rule;
- `metadata.variant_key`: the assigned variant, for `experiment_split` only;
- `metadata.id`, `metadata.version` and `metadata.has_experiment`: from the definition, read from the definitions snapshot that produced the result.

The record SHALL NOT carry an experiment ID, a holdout ID or an assignment seed, and SHALL NOT be marked `failed`. Legacy getters SHALL render it as they render a `/flags?v=4` record: a boolean as it is, a string as the string, `null` as `false`, and a number or an object as `true`, with the value as its payload, which payload getters return decoded. A change that a caller makes to a returned object SHALL NOT change the definition or a later result.

#### Scenario Outline: Legacy getters render each return type (@server)
- **GIVEN** the config version 2 flag <flag> evaluates locally to <value> for distinct id "person-example"
- **WHEN** the legacy flag getter and the legacy payload getter read it
- **THEN** the flag getter returns <rendering> and the payload getter returns <payload>

  | flag | value | rendering | payload |
  | "layout-preview" | `true` | `true` | no payload |
  | "checkout-copy" | `"short"` | `"short"` | no payload |
  | "results-per-page" | `20` | `true` | `20` |
  | "search-ranking" | `{"model": "semantic", "boost": 1.5}` | `true` | `{"model": "semantic", "boost": 1.5}` |

### Requirement: Events of locally evaluated config version 2 flags

A read of a locally evaluated config version 2 flag SHALL send the events that a remote result with the same record sends, built by the same step from the local record, with `locally_evaluated` set to `true`. `$feature_flag_called` carries the config version 2 attribution of `feature-flag-called-tracker` and the definition's `$feature_flag_id` and `$feature_flag_version`. A complete experiment split also sends `$experiment_exposure`, as `experiment-exposure` defines. The dedupe keys do not change, so a remote result that repeats a local assignment is not a second exposure. A result that a remote fallback supplied keeps `locally_evaluated` `false`. Evaluating a flag only to resolve a dependency sends no event.

#### Scenario: A locally evaluated targeted release sends its flag-called event (@server)
- **GIVEN** the config version 2 flag "layout-preview" (id 302, version 7) evaluates locally to `true` from the targeted release rule "11111111-1111-4111-8111-111111111111"
- **WHEN** it is read and captures are flushed
- **THEN** one `$feature_flag_called` event is received with:
  | property | value |
  | locally_evaluated | true |
  | $feature_flag_config_version | 2 |
  | $feature_flag_reason_code | targeting_match |
  | $feature_flag_rule_id | 11111111-1111-4111-8111-111111111111 |
  | $feature_flag_rule_type | targeted_release |
  | $feature_flag_response | true |
  | $feature_flag_id | 302 |
  | $feature_flag_version | 7 |
- **AND** it has no `$feature_flag_reason` and no `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is received

#### Scenario: A locally evaluated experiment split sends both events (@server)
- **GIVEN** the number flag "results-per-page" assigns distinct id "person-example" the variant "control", with the value `20`, from the experiment rule "11111111-1111-4111-8111-111111111111"
- **WHEN** it is read and captures are flushed
- **THEN** one `$experiment_exposure` event is received with `locally_evaluated` true, `$feature_flag_variant_key` "control", `$feature_flag_rule_id` "11111111-1111-4111-8111-111111111111" and `$feature_flag_response` true
- **AND** the `$feature_flag_called` event has `$feature_flag_reason_code` "experiment_split" and `$feature_flag_variant_key` "control"

#### Scenario: An inactive flag reports flag_disabled without a rule (@server)
- **GIVEN** the config version 2 flag "seasonal-theme" is inactive
- **WHEN** it is read and captures are flushed
- **THEN** one `$feature_flag_called` event is received with `locally_evaluated` true, `$feature_flag_config_version` 2, `$feature_flag_reason_code` "flag_disabled" and `$feature_flag_response` false
- **AND** it has no `$feature_flag_rule_id`, `$feature_flag_rule_type` or `$feature_flag_variant_key`
- **AND** no `$experiment_exposure` event is received

#### Scenario: A remote fallback reports the remote record (@server)
- **GIVEN** local evaluation of "example-display-key" is inconclusive, and the remote fallback returns a config version 2 record
- **WHEN** it is read and captures are flushed
- **THEN** the `$feature_flag_called` event has `locally_evaluated` false and the attribution of the remote record

### Requirement: Dates are read in UTC

The config version 2 evaluator SHALL read a date, or a date and time, without an offset in UTC, in a filter value and in a property value, and SHALL resolve a relative date from the current time in UTC. A value with `Z` or an offset denotes that instant. The SDK SHALL pass UTC to the evaluator and SHALL NOT use the host's timezone. The only exception is the in-process replay of "Evidence for the harness capability", which passes each case's own timezone.

The flags service reads such values in the project's timezone, and the definitions feed does not carry it. In a project that is not on UTC, a local and a remote result can therefore differ for a person whose date lies within the project's UTC offset of a boundary. Config version 1 local evaluation behaves the same way when it has no project timezone. A later change can add the project's timezone to the feed as an optional field.

#### Scenario Outline: A filter date without an offset is midnight UTC (@server)
- **GIVEN** the boolean flag "launch-window" has one rule that targets persons whose "signed_up_at" `is_date_before` "2024-06-15"
- **WHEN** it is read locally with person property "signed_up_at" equal to <signed_up_at>
- **THEN** the result is <result>
- **AND** no remote evaluation request is sent

  | signed_up_at | result |
  | "2024-06-15T00:30:00+02:00" | `true` |
  | "2024-06-14T23:30:00-02:00" | `false` |

#### Scenario: A relative date counts back from the current time in UTC (@server)
- **GIVEN** the SDK clock is fixed at "2024-03-31T12:00:00Z"
- **AND** the boolean flag "recent-signup" has one rule that targets persons whose "signed_up_at" `is_date_after` "-1d"
- **WHEN** it is read locally with person property "signed_up_at" equal to "2024-03-30T12:30:00Z"
- **THEN** the result is `true`, because one day before the current time in UTC is "2024-03-30T12:00:00Z"
- **AND** the result does not depend on the host's timezone: counted on the wall clock of Europe/Oslo, where the clocks changed that night, the boundary would be "2024-03-30T13:00:00Z"

### Requirement: Evidence for the harness capability

An SDK SHALL replay in process, through its config version 2 evaluator, every case of the contract's boolean, value, experiment and local evaluation corpora and its hash vectors, and SHALL check each case against the local outcome that `rules/local_outcomes.json` gives it. The replay evaluates each case with its own context, through a private test seam where the public API cannot pass it: a complete property map, the case's timezone and current time, and the hash that a white-box hash case fixes. The SDK SHALL declare the harness capability `feature_flags_local_evaluation_v2` only in a release that requests `v=2`, and only when that replay and the harness's black-box local evaluation suite pass.

#### Scenario: The capability is declared with the version 2 request (@server)
- **GIVEN** an SDK release that evaluates config version 2 flags but does not yet request `v=2`
- **WHEN** its harness adapter reports its capabilities
- **THEN** it does not declare `feature_flags_local_evaluation_v2`
