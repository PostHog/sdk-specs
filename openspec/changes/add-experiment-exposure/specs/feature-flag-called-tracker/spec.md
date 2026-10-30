## ADDED Requirements

### Requirement: Config version 2 attribution on `$feature_flag_called`

When the evaluation details that supplied a read's value come from a config version 2 record that the SDK read without a parse error, the `$feature_flag_called` event SHALL carry these properties:

| Property | Source | Presence |
| --- | --- | --- |
| `$feature_flag_config_version` | `metadata.config_version`, the number `2` | always |
| `$feature_flag_reason_code` | `reason.code` | whenever the record has a reason code |
| `$feature_flag_rule_id` | `metadata.rule_id` | by the table below |
| `$feature_flag_rule_type` | `metadata.rule_type` | by the table below |
| `$feature_flag_variant` | `metadata.variant_key` | by the table below |

`$feature_flag_config_version` is the flag's config version. It is distinct from `$feature_flag_version`, the version of the flag's row. `$feature_flag_reason_code` is the machine-readable reason code; `$feature_flag_reason` stays the human-readable description where the SDK sends it.

The rule fields depend on the reason code:

| Reason code | `$feature_flag_rule_id` and `$feature_flag_rule_type` | `$feature_flag_variant` |
| --- | --- | --- |
| `experiment_split` with rule type `experiment`, a rule ID and a variant key | sent | sent |
| `experiment_split` with any of those three missing (a malformed split, see `experiment-exposure`) | not sent | not sent |
| `targeting_match` (a targeted release or percentage rollout match) | sent when present | not sent |
| `rollout_miss` (a terminal rollout exclusion), `experiment_paused`, `holdout` | sent when present | not sent |
| `no_rule_match`, `missing_group_key`, `flag_disabled`, `dependency_error`, `error`, any `failed` record, and any other reason code | not sent | not sent |

The SDK SHALL take these values only from the record that supplied the value. It SHALL NOT send a field that the table marks "not sent", even when the record carries it.

A config version 2 `$feature_flag_called` event SHALL NOT carry `$feature_flag_experiment_id`, a holdout ID, `$feature_flag_forced_variant`, or an assignment seed anywhere in the event.

For a config version 2 record, `$feature_flag_response` SHALL be the legacy rendering of the record's value on every read path, including typed reads: `true` or `false` for a boolean, the string for a string, `false` for `null`, and `true` for a number or an object. It SHALL NOT be a caller default. This holds until an event schema for number and object values is decided.

The SDK SHALL NOT add any of these properties for a config version 1 record, a record from a server that does not send typed values, a missing flag, a bootstrapped value or a client-side override. Those events do not change.

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
  | $feature_flag_variant        | test                                 |

#### Scenario: A holdout names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `holdout`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "holdout", `$feature_flag_rule_type` "experiment" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant`

#### Scenario: A terminal rollout exclusion names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `rollout_miss`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "rollout_miss" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant`

#### Scenario: A paused experiment names the rule but no variant
- **GIVEN** the record for "checkout-flow" has value false, reason code `experiment_paused`, config version 2, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_reason_code` "experiment_paused" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant`

#### Scenario: Targeted and percentage matches have no variant
- **GIVEN** the record for "beta-ui" has value true, reason code `targeting_match`, config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **AND** the record for "new-nav" has value true, reason code `targeting_match`, config version 2, rule type `percentage_rollout` and rule id "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45"
- **WHEN** reads of "beta-ui" and "new-nav" emit `$feature_flag_called`
- **THEN** each event has `$feature_flag_reason_code` "targeting_match" and its record's rule type and rule id
- **AND** neither event has `$feature_flag_variant`

#### Scenario: A no-rule match carries no rule identity
- **GIVEN** the record for "beta-ui" has value false, reason code `no_rule_match` and config version 2
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "no_rule_match"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`

#### Scenario: A failed record carries no rule identity
- **GIVEN** the record for "beta-ui" has `failed` true, reason code `dependency_error` and config version 2
- **WHEN** a read of "beta-ui" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_config_version` 2 and `$feature_flag_reason_code` "dependency_error"
- **AND** it has none of `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`

#### Scenario: A forbidden field in the record is not sent
- **GIVEN** the record for "checkout-flow" has reason code `holdout`, config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and also a variant key "test"
- **WHEN** a read of "checkout-flow" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **AND** it has no `$feature_flag_variant`

#### Scenario: A number value is reported with its legacy rendering
- **GIVEN** the record for "search-ranking" has the number value 25, reason code `targeting_match`, config version 2, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **WHEN** a read of "search-ranking" emits `$feature_flag_called`
- **THEN** the event has `$feature_flag_response` true

#### Scenario: Config version 1 events do not change
- **GIVEN** the record for "legacy-layout" has value "compact", reason code `condition_match`, config version 1 and variant key "compact"
- **WHEN** a read of "legacy-layout" emits `$feature_flag_called`
- **THEN** the event has none of `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`

### Requirement: Config version 2 dedupe key

For a `$feature_flag_called` event that carries `$feature_flag_config_version` 2, the tracker key SHALL include, in addition to its existing inputs (the flag key, the `$feature_flag_response` value, and the distinct ID and canonical group context where the SDK includes them):

- the config version;
- the reason code, as sent on the event;
- the rule ID, as sent on the event;
- the rule type, as sent on the event;
- the variant key, as sent on the event.

An absent reason code, rule ID, rule type or variant key SHALL be a key component distinct from every present value. The key SHALL be the same on every read path, so typed and legacy reads of the same flag and outcome dedupe together. The local or remote source, the request ID and the evaluation time SHALL NOT be part of the key. The key for every other event, including every config version 1 event, does not change, and the tracker's reset, eviction and event-decision rules do not change.

As a result, a repeated read of the same outcome emits no second event, while each of these emits a new event for the same identity, flag and value: another arm of an A/A test, another experiment rule, a holdout after an arm of the same rule, another outcome of the same rule with no variant (for example a holdout, then a paused experiment), a release rule that ships an experiment's winning value, and a flag that moves from config version 1 to config version 2.

#### Scenario: A repeated read of the same outcome emits one event
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** "checkout-flow" is read twice for distinct id "user-123"
- **THEN** exactly one `$feature_flag_called` event is enqueued for "checkout-flow"

#### Scenario: Another A/A arm with the same value emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "pricing-page" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** a later evaluation assigns "user-123" variant key "test" in the same rule, still with value true
- **AND** "pricing-page" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_variant` "test"

#### Scenario: A holdout after an arm of the same rule emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "checkout-flow" with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** a later evaluation puts "user-123" in the holdout of the same rule, with value false
- **AND** "checkout-flow" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_reason_code` "holdout" and no `$feature_flag_variant`

#### Scenario: A paused experiment after a holdout of the same rule emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "checkout-flow" with value false, reason code `holdout`, rule type `experiment` and rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"
- **WHEN** the experiment is paused and the next evaluation for "user-123" reports reason code `experiment_paused` for the same rule, with value false
- **AND** "checkout-flow" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_reason_code` "experiment_paused" and `$feature_flag_rule_id` "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13"

#### Scenario: Shipping the winner emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** the experiment rule is replaced by a targeted release rule with rule id "d2b8c6f4-1e3a-4c5d-9f07-6a8b2c4e0d13" that returns true
- **AND** "checkout-flow" is read again for "user-123"
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_rule_id` "d2b8c6f4-1e3a-4c5d-9f07-6a8b2c4e0d13"

#### Scenario: Moving a flag to config version 2 emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for the config version 1 flag "beta-ui" with value true
- **WHEN** "beta-ui" becomes a config version 2 flag whose record for "user-123" has value true, reason code `targeting_match`, rule type `targeted_release` and rule id "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96"
- **AND** "beta-ui" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_config_version` 2

## MODIFIED Requirements

### Requirement: Minimal event mode for non-experiment flags

The SDK SHALL support a server-controlled "minimal event" mode that reduces `$feature_flag_called` event properties to a fixed allowlist instead of the full enriched properties dict, when both of the following hold:

- **The server has enabled the gate for the team.** Reported as `minimalFlagCalledEvents: true` on the remote `/flags` (v2) response, or `minimal_flag_called_events: true` on the local-evaluation flag-definitions payload used by SDKs that support local evaluation. Absent, falsy, or unrecognized-shape responses mean the gate is off.
- **The evaluated flag's server-reported experiment linkage is exactly `false`.** Flags report `has_experiment` as part of their evaluation metadata. If `has_experiment` is `true` (flag linked to an experiment), or unknown/missing (legacy response shape, stale cache, older server), the SDK MUST NOT minimize — it sends the full event. Only an explicit `false` triggers minimization.

When gated on, the event's properties SHALL be reduced to an allowlist covering, at minimum, these categories:

- **Flag identity and outcome** — the flag key, its resolved value, and the experiment-linkage flag itself (e.g. `$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`).
- **Evaluation debug scalars** the server/SDK already attaches (e.g. `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`).
- **Group and person-processing context** needed for correct downstream handling (e.g. `$groups`, `$process_person_profile`).
- **Session/SDK linkage** (e.g. `$session_id`, `$lib`, `$lib_version`) and, on server SDKs, the server marker (e.g. `$is_server`).
- **Static, low-cardinality platform/runtime identity properties** the SDK already attaches to every event, kept for platform/runtime breakdowns on flag-call debugging (e.g. `$os`/`$python_version` on posthog-python; the equivalent OS/runtime identity fields on other SDKs).
- **Session-attribution properties** — `$referring_domain` and the canonical campaign/click-id params the SDK already registers as super properties (e.g. `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, and click-id params such as `gclid`/`fbclid`). Web-analytics session-initial attribution (UTM values, channel type) is read from the **first event in a session**, and a minimized event can be that first event; stripping these would silently null out the whole session's attribution. Full `$referrer` remains excluded — only `$referring_domain` and the bare campaign-param keys survive minimization.
- **Config version 2 attribution** — `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`, whenever the event carries them (see "Config version 2 attribution on `$feature_flag_called`"). A config version 2 flag can report `has_experiment` as `false` while one of its experiment rules assigns an arm, because no experiment links to that rule yet, so a minimized event can be the only flag-called record of the rule and the arm. Ingestion also relies on `$feature_flag_config_version` to tell these events apart from config version 1 events.

Everything else — including super properties, custom event properties passed by the caller, and other enriched context tags — SHALL be stripped from a minimized event.

> Note (non-normative): the exact property allowlist is stated here at the category level, not as one fixed literal list, because SDKs differ in exactly which static platform fields they attach. posthog-python's allowlist (`$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`, `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`, `$groups`, `$process_person_profile`, `$session_id`, `$lib`, `$lib_version`, `$is_server`, `$geoip_disable`, `$os`, `$os_version`, `$os_distro`, `$python_runtime`, `$python_version`) is the reference implementation other SDKs describe mirroring. Every SDK's allowlist also includes the config version 2 attribution properties listed above.

If the gate is absent, the `has_experiment` signal is missing/unknown, or the flag is linked to an experiment, the SDK SHALL send the full, unminimized event unchanged — minimization fails safe to "send everything" rather than risk silently dropping properties a consumer depends on.

The gate SHALL persist alongside cached flag/local-evaluation definition state (including through external/shared `flag_definition_cache`-style provider round-trips) so it survives polls, `304 Not Modified` responses, and cache reloads without requiring a fresh network round trip to re-learn it.

#### Scenario: Full event when the server does not report the gate (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" has no reported `has_experiment` and the server reports no minimal-event gate
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Full event when the flag's experiment linkage is unknown (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" has no reported `has_experiment` value
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Full event when the flag is linked to an experiment (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key           | value |
  | experiment-ui | true  |
- **AND** the flag "experiment-ui" reports `has_experiment` as true
- **WHEN** get feature flag "experiment-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Minimal event when gated on and the flag has no experiment (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" reports `has_experiment` as false
- **AND** a super property "team" with value "growth" is registered
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |
  | $feature_flag_has_experiment | false |
- **AND** the enqueued event properties should not include "team"

#### Scenario: Minimal event preserves session-attribution properties but not the full referrer (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" reports `has_experiment` as false
- **AND** a super property "$referring_domain" with value "google.com" is registered
- **AND** a super property "utm_source" with value "google" is registered
- **AND** a super property "$referrer" with value "https://google.com/search?q=posthog" is registered
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event properties should include:
  | property           | value      |
  | $referring_domain  | google.com |
  | utm_source         | google     |
- **AND** the enqueued event properties should not include "$referrer"

#### Scenario: Gate persists across a local-evaluation definitions refresh (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and a personal API key for local evaluation
- **AND** the local-evaluation definitions payload reports `minimal_flag_called_events` as true
- **AND** local feature flag definitions include a flag "beta-ui" with `has_experiment` false returning true
- **WHEN** the local-evaluation definitions are refreshed via a `304 Not Modified` response
- **AND** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should be minimized per the allowlist

#### Scenario: Minimal event keeps config version 2 attribution (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** the loaded record for "checkout-flow" has value true, reason code `experiment_split`, config version 2, rule type `experiment`, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13", variant key "test" and `has_experiment` false
- **AND** a super property "team" with value "growth" is registered
- **WHEN** get feature flag "checkout-flow" is called
- **THEN** the enqueued "$feature_flag_called" event properties should include:
  | property                     | value                                |
  | $feature_flag                | checkout-flow                        |
  | $feature_flag_response       | true                                 |
  | $feature_flag_config_version | 2                                    |
  | $feature_flag_reason_code    | experiment_split                     |
  | $feature_flag_rule_id        | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
  | $feature_flag_rule_type      | experiment                           |
  | $feature_flag_variant        | test                                 |
- **AND** the enqueued event properties should not include "team"
