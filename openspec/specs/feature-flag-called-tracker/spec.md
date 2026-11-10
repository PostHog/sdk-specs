# Feature Flag Called Tracker Specification

## Purpose

`feature-flag-called-tracker` is the internal deduplication component that suppresses duplicate `$feature_flag_called` events for the same flag evaluation outcome.

Its job is to prevent analytics noise when application code repeatedly reads the same flag without the underlying flag value changing.

## Applicability

`both` — audited client and server SDKs use an internal tracker/cache to dedupe `$feature_flag_called` events, though the dedupe key and eviction policy differ.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
shouldTrack(distinctId?, flagKey, value, groups?): boolean
markSeen(distinctId?, flagKey, value, groups?): void
reset(): void
```

In some SDKs, `shouldTrack` and `markSeen` are combined into one atomic "add if unseen" operation.

## Behavior

1. **Build a dedupe key from the flag access.** Common inputs are:
   - feature flag key
   - evaluated response/value (`true`, `false`, variant string, or `null`/`undefined`)
   - in many server/mobile SDKs, `distinct_id` as well
   - when provided to server-side evaluation, group context (`groups`, such as group type/key pairs) as well
   Group context SHOULD be normalized as a semantic mapping, for example sorted stringified `(group_type, group_key)` pairs, so incidental map/dictionary insertion order does not create a different dedupe key.
   For a config version 2 result, the key also includes the config version, reason code, rule ID, rule type and variant key, as sent on the event (see "Config version 2 dedupe key"). `$experiment_exposure` is deduped in its own namespace, not by this tracker (see `experiment-exposure`).
2. **Check whether this combination was already reported.**
3. **Suppress duplicate tracking events.** If the same combination has already been seen, do not emit another `$feature_flag_called` event.
4. **Allow new tracking when the response or evaluation context changes.** If a flag's value changes for the same key, or if a server-side call evaluates the same flag/value for a different `distinct_id` or group context, allow a new `$feature_flag_called` event.
5. **Reset on flag change and lifecycle boundaries.** When feature flag state changes, caches are reset, identity is reset, or the SDK is closed/shut down, clear the dedupe tracker so post-reset/reloaded SDK state can emit fresh tracking events and shutdown state cannot leak across SDK lifetimes. On client-side flag reloads, SDKs MAY retain the tracker if they can reliably compare the complete relevant flag state before and after reload (including flag keys, values, payloads, and other cached flag metadata used by accessors) and determine it is unchanged; otherwise, they SHOULD clear the tracker after reload.
6. **Expose tracking controls unevenly at the wrapper layer when applicable.** For example, Flutter delegates to the underlying native/browser trackers. Flutter 6.0 exposes a per-call `sendFeatureFlagEvent` option on `getFeatureFlag(...)`, `isFeatureEnabled(...)` and `getFeatureFlagResult(...)`; before 6.0 only `getFeatureFlagResult(sendEvent: ...)` had one, and `getFeatureFlag(...)` and `isFeatureEnabled(...)` always used the default tracking path.
7. **Cap memory usage where needed.** Larger-scale implementations evict old entries using bounded maps or LRU-style caches. When a bounded tracker reaches its capacity, it SHOULD evict the oldest or least-recently-used entries incrementally. Capacity pressure SHOULD NOT clear the entire tracker, because doing so can flood analytics with duplicate `$feature_flag_called` events. Full tracker clears are reserved for explicit lifecycle/context boundaries such as observed flag-state change/cache reset, identity reset, or SDK close/shutdown.

## State & lifecycle

### State read

- in-memory map/LRU cache of previously-reported flag/value/context combinations

### State written

- newly seen dedupe entries
- tracker reset/eviction state

### Lifecycle behavior

- The tracker starts empty when the SDK initializes.
- Each flag access that would emit `$feature_flag_called` consults the tracker first.
- Flag reloads reset the tracker when the SDK cannot reliably determine whether relevant flag state changed, or when it detects a change in flag keys, values, payloads, or other cached flag metadata used by accessors.
- Client SDKs MAY keep tracker state across a flag reload when they can reliably compare the complete relevant flag state and determine it is unchanged.
- Capacity-based eviction SHOULD remove only selected old/LRU entries instead of clearing the entire tracker.
- SDKs that support identity reset flows MUST clear the tracker because the relevant flag-evaluation context changed.
- SDK close/shutdown flows MUST clear the tracker so in-memory dedupe state does not outlive the SDK instance.
- Wrapper SDKs may not own a separate tracker at all. Flutter inherits tracker lifecycle from the underlying native/browser SDKs on iOS, macOS, Android and web; on Windows and Linux its pure-Dart client owns the tracker.

## Error handling

- Tracker operations should not throw in normal operation.
- Missing or uninitialized tracker state should be treated as "nothing seen yet".
- If value serialization/comparison is imperfect, the failure mode should be extra tracking or under-tracking, not application crashes.

## Concurrency & ordering guarantees

- Lookups and updates are synchronized or serialized by the SDK's runtime model.
- Atomic "check and add" behavior is preferred so concurrent accesses do not double-emit the same `$feature_flag_called` event.
- Reset operations take effect immediately for subsequent flag accesses.

## Interactions

- **`get-feature-flag` / `is-feature-enabled` / `get-feature-flag-result`** — all commonly use this tracker before capturing `$feature_flag_called`.
- **`get-feature-flag-payload`** — some SDKs route payload lookups through the same tracking/dedupe machinery, while others suppress tracking or expose only a compatibility wrapper.
- **feature-flag cache reloads** — reset the tracker when relevant flag state may have changed. SDKs MAY avoid clearing on reload when they can reliably compare the complete relevant cached flag state, including values and payloads, and determine it is unchanged.
- **identity resets / context changes** — clear the tracker because subsequent evaluations use a new user context.
- **server-side group context** — where groups are provided for feature-flag evaluation, the group type/key mapping is part of the dedupe context so the same user, flag, and value can be tracked separately for different group evaluations. Equivalent group mappings should dedupe even if represented in a different map/dictionary order.
- **SDK close / shutdown** — clears the tracker as part of teardown so dedupe state does not leak across SDK lifetimes.
- **`experiment-exposure`** — a tracked read of a config version 2 experiment split also emits `$experiment_exposure`. That event has its own bounded dedupe namespace, which identity reset and shutdown clear but a flags reload does not. The two events dedupe independently.

## Requirements

### Requirement: Canonical feature-flag-called-tracker behavior

The SDK SHALL implement the canonical `feature-flag-called-tracker` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Tracker emits the first flag-called event for a value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |

#### Scenario: Tracker suppresses duplicate events for the same flag value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** get feature flag "beta-ui" is called again
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

#### Scenario: Tracker emits again when the flag value changes (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** cached feature flag "beta-ui" changes to "false"
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker suppresses duplicates for the same server group context (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
  | team    | team-1      |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | team    | team-1      |
  | company | company-123 |
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "company-beta"

#### Scenario: Tracker emits again when server group context changes (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-456 |
- **THEN** two "$feature_flag_called" events should be enqueued for flag "company-beta"

#### Scenario: Tracker clears on identity reset (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** reset is called
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker clears on SDK shutdown (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** shutdown is called
- **THEN** feature flag called tracker state should be empty

### Requirement: Minimal event mode for non-experiment flags

The SDK SHALL support a server-controlled "minimal event" mode that reduces `$feature_flag_called` event properties to a fixed allowlist instead of the full enriched properties dict, when both of the following hold:

- **The server has enabled the gate for the team.** Reported as `minimalFlagCalledEvents: true` on the remote `/flags` response (API `v=2` and later), or `minimal_flag_called_events: true` on the local-evaluation flag-definitions payload used by SDKs that support local evaluation. Absent, falsy, or unrecognized-shape responses mean the gate is off.
- **The evaluated flag's server-reported experiment linkage is exactly `false`.** Flags report `has_experiment` as part of their evaluation metadata. If `has_experiment` is `true` (flag linked to an experiment), or unknown/missing (legacy response shape, stale cache, older server), the SDK MUST NOT minimize — it sends the full event. Only an explicit `false` triggers minimization.

When gated on, the event's properties SHALL be reduced to an allowlist covering, at minimum, these categories:

- **Flag identity and outcome** — the flag key, its resolved value, and the experiment-linkage flag itself (e.g. `$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`).
- **Evaluation debug scalars** the server/SDK already attaches (e.g. `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`). A config version 2 event has no `$feature_flag_reason`; its `$feature_flag_reason_code` takes that place.
- **Group and person-processing context** needed for correct downstream handling (e.g. `$groups`, `$process_person_profile`).
- **Session/SDK linkage** (e.g. `$session_id`, `$lib`, `$lib_version`) and, on server SDKs, the server marker (e.g. `$is_server`).
- **Static, low-cardinality platform/runtime identity properties** the SDK already attaches to every event, kept for platform/runtime breakdowns on flag-call debugging (e.g. `$os`/`$python_version` on posthog-python; the equivalent OS/runtime identity fields on other SDKs).
- **Session-attribution properties** — `$referring_domain` and the canonical campaign/click-id params the SDK already registers as super properties (e.g. `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, and click-id params such as `gclid`/`fbclid`). Web-analytics session-initial attribution (UTM values, channel type) is read from the **first event in a session**, and a minimized event can be that first event; stripping these would silently null out the whole session's attribution. Full `$referrer` remains excluded — only `$referring_domain` and the bare campaign-param keys survive minimization.
- **Config version 2 attribution** — on a config version 2 event only, `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant_key`, whenever the event carries them (see "Config version 2 attribution on `$feature_flag_called`"). A minimized config version 1 event keeps the allowlist it has today and strips these names like any other property, even when a super property or caller property uses one of them. A config version 2 flag can report `has_experiment` as `false` while one of its experiment rules assigns a variant, because no experiment links to that rule yet, so a minimized event can be the only flag-called record of the rule and the variant. Ingestion also relies on `$feature_flag_config_version` to tell these events apart from config version 1 events.

Everything else — including super properties, custom event properties passed by the caller, and other enriched context tags — SHALL be stripped from a minimized event.

> Note (non-normative): the exact property allowlist is stated here at the category level, not as one fixed literal list, because SDKs differ in exactly which static platform fields they attach. posthog-python's allowlist (`$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`, `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`, `$groups`, `$process_person_profile`, `$session_id`, `$lib`, `$lib_version`, `$is_server`, `$geoip_disable`, `$os`, `$os_version`, `$os_distro`, `$python_runtime`, `$python_version`) is the reference implementation other SDKs describe mirroring. For config version 2 events only, every SDK's allowlist also includes the config version 2 attribution properties listed above; config version 1 events use the allowlist above unchanged. `$feature_flag_reason` stays on the allowlist for config version 1 events; config version 2 events never carry it.

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
  | $feature_flag_variant_key    | test                                 |
- **AND** the enqueued event properties should not include "team"
- **AND** the enqueued event properties should not include "$feature_flag_reason"

#### Scenario: A minimized config version 1 event does not keep attribution names (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" is a config version 1 flag that reports `has_experiment` as false
- **AND** a super property "$feature_flag_rule_id" with value "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" is registered
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should be minimized per the allowlist
- **AND** the enqueued event properties should not include "$feature_flag_rule_id"
- **AND** the enqueued event properties should not include "$feature_flag_config_version"

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

### Requirement: Config version 2 dedupe key

For a `$feature_flag_called` event that carries `$feature_flag_config_version` 2, the tracker key SHALL include, in addition to its existing inputs (the flag key, the `$feature_flag_response` value, and the distinct ID and canonical group context where the SDK includes them):

- the config version;
- the reason code, as sent on the event;
- the rule ID, as sent on the event;
- the rule type, as sent on the event;
- the variant key, as sent on the event.

An absent reason code, rule ID, rule type or variant key SHALL be a key component distinct from every present value. The key SHALL be the same on every read path, so typed and legacy reads of the same flag and outcome dedupe together. The local or remote source, the request ID and the evaluation time SHALL NOT be part of the key. For these events the tracker SHALL add the key only after capture handles the event (accepts it, or the application's before-send hook discards it), and a failed capture (a throw, a full or closed queue, opt-out or a disabled SDK) adds no key, as "Exposure capture is built in one best-effort step" in `experiment-exposure` defines. The key for every other event, including every config version 1 event, does not change, and the tracker's reset, eviction and event-decision rules do not change.

As a result, a repeated read of the same outcome emits no second event, while each of these emits a new event for the same identity, flag and value: another variant of an A/A test, another experiment rule, a holdout after a variant of the same rule, another outcome of the same rule with no variant (for example a holdout, then a paused experiment), a release rule that ships an experiment's winning value, and a flag that moves from config version 1 to config version 2.

#### Scenario: A repeated read of the same outcome emits one event
- **GIVEN** the record for "checkout-flow" is a complete config version 2 experiment split with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** "checkout-flow" is read twice for distinct id "user-123"
- **THEN** exactly one `$feature_flag_called` event is enqueued for "checkout-flow"

#### Scenario: Another A/A variant with the same value emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "pricing-page" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** a later evaluation assigns "user-123" variant key "test" in the same rule, still with value true
- **AND** "pricing-page" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_variant_key` "test"

#### Scenario: A holdout after a variant of the same rule emits a new event
- **GIVEN** a read for distinct id "user-123" emitted `$feature_flag_called` for "checkout-flow" with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
- **WHEN** a later evaluation puts "user-123" in the holdout of the same rule, with value false
- **AND** "checkout-flow" is read again
- **THEN** a second `$feature_flag_called` event is enqueued with `$feature_flag_reason_code` "holdout" and no `$feature_flag_variant_key`

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
