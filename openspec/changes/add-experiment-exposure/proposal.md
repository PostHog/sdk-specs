## Why

Experiment analysis counts `$experiment_exposure` events. SDKs do not send them today. Ingestion makes them by copying some multivariate `$feature_flag_called` events and reading the variant from the string in `$feature_flag_response`. That inference cannot:

- tell an experiment variant from an ordinary string value;
- tell apart variants that return the same value, as in an A/A test;
- tell apart two experiment rules on one flag, or an experiment from a holdout or a rollout on the same flag;
- handle variants whose values are booleans, numbers or objects.

Flags with config version 2 ("flag rules v2") are built from ordered rules, and one rule type is `experiment`. In a `/flags?v=4` response, each flag record carries the exact reason code, rule ID, rule type and variant key. The public wire contract in [posthog-sdk-test-harness 1.27.0](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.27.0) (`contracts/feature_flag_rules_v2`, contract 8.0.0) defines those records, the property projections of both events, and which records produce an exposure. The rule that rule ID and rule type are sent together or not at all needs the next contract, 9.0.0 ([posthog-sdk-test-harness#101](https://github.com/PostHog/posthog-sdk-test-harness/pull/101)): contract 8.0.0 rejects a `$feature_flag_called` for `targeting_match`, `rollout_miss`, `experiment_paused` or `holdout` that leaves both out. The SDK knows exactly when a read assigned a variant, and which variant, so it should send the exposure itself.

Ingestion is ready for this. It leaves a directly captured `$experiment_exposure` untouched, and it does not copy a `$feature_flag_called` event that carries `$feature_flag_config_version` 2 ([PostHog/posthog#125449](https://github.com/PostHog/posthog/pull/125449)).

[PostHog/sdk-specs#104](https://github.com/PostHog/sdk-specs/pull/104) (typed flag values) leaves `$experiment_exposure`, the rule attribution properties on `$feature_flag_called`, and the dedupe-key change to this change.

## What Changes

- A read that reports `$feature_flag_called` (its feature flag event decision is `true`) also emits one `$experiment_exposure`, deduped on its own key, when the evaluation details that supplied its value are a complete config version 2 experiment split: reason code `experiment_split`, rule type `experiment`, a rule ID and a variant key, and the value was not bootstrapped or overridden. Nothing else emits it.
- The decision uses those evaluation details, not the value the read returned. A read that returned its caller default because the value is `null` or `false` still reports the assignment. A typed read of the wrong type sends neither event and takes no dedupe slot.
- A malformed split (any of rule type `experiment`, rule ID or variant key missing, where a rule ID that is not a UUID counts as missing) emits no exposure. Its `$feature_flag_called` keeps config version 2 and the reason code and omits the whole rule tuple. The SDK never guesses the missing parts.
- `$feature_flag_called` for config version 2 results gains `$feature_flag_config_version`, `$feature_flag_reason_code`, `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant`, by a per-reason presence table (the rule ID and rule type are sent as a pair or not at all), and drops `$feature_flag_reason`, the human-readable description that `$feature_flag_reason_code` replaces. A missing or unknown reason code keeps config version 2 and the raw code, if any, with no rule attribution and no exposure. Config version 1 events keep it. No event carries an experiment ID, a holdout ID or an assignment seed.
- `$experiment_exposure` carries the flag key, `$feature_flag_response`, `$feature_flag_variant`, `$feature_flag_rule_id` and `locally_evaluated`, plus, when available, the flag ID, version, request ID, evaluation time, definitions-loaded time, library identity and groups. It carries no rule type, reason code, config version or source marker: those are constants for an experiment split, and the rule ID marks the event as SDK-sent.
- `$feature_flag_response` keeps the legacy rendering on both events (`true` for number and object values, `false` for `null`), until a number and object event schema exists. The variant is `$feature_flag_variant`.
- The `$feature_flag_called` dedupe key for config version 2 results also includes the config version, reason code, rule ID, rule type and variant key. `$experiment_exposure` gets its own bounded dedupe namespace keyed on distinct ID, groups, flag key, config version, rule ID and variant key. The value, request ID, evaluation time and local or remote source are not in the exposure key. A key is added only after capture accepts its event, each event is attempted independently, and a flags reload never clears the exposure namespace.
- The feature flag event decision (per-read option, client-level default) governs both events. Payload reads stay silent by default; an opted-in payload read that evaluates the flag follows the trigger, and a caller-supplied match value never sends an exposure or reserves its key.
- Minimal-event mode keeps the new attribution properties on config version 2 events. Config version 1 events keep today's allowlist.
- An SDK that evaluates config version 2 flags locally emits the same exposure with `locally_evaluated` true. Config version 1 flags never get a direct SDK exposure.
- Both events are built in one best-effort step that reads only the evaluation details, so a wrapper such as an OpenFeature provider hook can reuse it.

No breaking changes. Config version 1 flags, their events and their dedupe are unchanged.

## Capabilities

### New Capabilities

- `experiment-exposure`: when an SDK emits `$experiment_exposure`, its properties, its dedupe, how the feature flag event decision, bootstrap, overrides and local evaluation affect it, and the fail-closed rule for malformed splits.

### Modified Capabilities

- `feature-flag-called-tracker`: config version 2 attribution properties on `$feature_flag_called`, the config version 2 dedupe key, and minimal-event mode keeping the attribution.
- `evaluate-flags`: snapshot reads report the exposure from the record the snapshot retained.

## Impact

- Specs only. No SDK code changes in this repository.
- SDKs that read `/flags?v=4` add the exposure, the attribution properties and the dedupe changes. posthog-python is first: [PostHog/posthog-python#1154](https://github.com/PostHog/posthog-python/pull/1154) is a draft based on main. It builds on [PostHog/posthog-python#1031](https://github.com/PostHog/posthog-python/pull/1031), which reads the v4 record and is released in posthog 7.83.0.
- Ingestion needs no further change.
- Experiment analysis of config version 2 flags reads the variant from `$feature_flag_variant` on SDK-sent exposures. That query work is outside this repository.

## Out of scope

- Typed flag accessors and the evaluation-details object. They are #104.
- Replacing `$feature_flag_response` on config version 2 events with a typed value property, and the PostHog features that read it.
- Custom exposure events that an experiment defines in place of `$experiment_exposure`.
- Experiment analysis queries, including how analysis picks the variant.
- The ingestion-derived exposure for config version 1 flags. It stays as it is.
- The local evaluation algorithm for config version 2 flags. This change only says what an SDK that has one emits.
- Changes to the `/flags` wire contract or the bootstrap format.
