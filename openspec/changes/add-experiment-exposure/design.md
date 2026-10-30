## Context

Experiment analysis counts `$experiment_exposure` events. Today ingestion creates them: it copies some multivariate `$feature_flag_called` events and takes the arm from the string in `$feature_flag_response`. That works for config version 1 multivariate flags, where the variant key is the value. It does not work for config version 2 flags:

- An arm's value can be a boolean, a string, a number or an object. A string value is not necessarily an arm, and a non-string value is invisible to the inference.
- Two arms can return the same value. An A/A test is the extreme case.
- One flag can hold several experiment rules, and a holdout or a rollout exclusion can return the same value as an arm.

A `/flags?v=4` record carries `value`, `failed`, `reason` (`code`, `condition_index`, `description`) and `metadata` (`id`, `version`, `description`, `has_experiment`, `config_version`, `rule_type`, `rule_id`, `variant_key`, `forced_variant`, `payload`). For a config version 2 flag the record says exactly which rule ended evaluation and, for an experiment split, which arm. The SDK holds that record when application code reads the flag, so it can send the exposure itself.

The public wire contract is `contracts/feature_flag_rules_v2` in [posthog-sdk-test-harness 1.26.0](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.26.0) (contract 7.0.0). This change relies on four of its files:

- `rules/response_presence.json`: which rule fields each reason code requires or forbids.
- `schemas/feature_flag_called_context.schema.json`: the closed projection of the flag-access properties on `$feature_flag_called`, including the malformed-split diagnostic.
- `schemas/experiment_exposure_properties.schema.json`: the closed projection of the required `$experiment_exposure` properties.
- `fixtures/wire/readers.json`: for each reader case, whether a reader emits an exposure.

This change does not alter the contract. It turns the contract into SDK behaviour: when to emit, what each event carries, and how dedupe works.

Ingestion already supports SDK-sent exposures. It does not touch a directly captured `$experiment_exposure`, and it does not copy a `$feature_flag_called` that carries `$feature_flag_config_version` 2 ([PostHog/posthog#125449](https://github.com/PostHog/posthog/pull/125449)).

The existing specs this change builds on:

- `feature-flag-called-tracker`: the dedupe tracker for `$feature_flag_called`, and "Minimal event mode for non-experiment flags".
- `evaluate-flags`: "Lazy feature-flag access tracking" and "Snapshot feature flag event control" (the per-read `sendFeatureFlagEvents` option).
- `get-feature-flag-result`: "Per-call feature flag event option name".
- `bootstrap`: "Bootstrapped flag reporting on `$feature_flag_called`".
- [PostHog/sdk-specs#104](https://github.com/PostHog/sdk-specs/pull/104) (draft): typed accessors. It defers the exposure, the attribution properties and the dedupe-key change to this change.

**Terminology.** Some existing specs call `$feature_flag_called` an "exposure". In this change "exposure" means `$experiment_exposure` only, and "flag-called event" means `$feature_flag_called`.

## Goals / Non-Goals

**Goals:**

- An exact exposure for every config version 2 experiment assignment that application code reads, and no exposure for anything else.
- Rule and arm attribution on `$feature_flag_called`, so flag analytics can tell rules and arms apart.
- Dedupe that keeps distinct assignments apart and does not double-count one assignment.
- No change for config version 1 flags or for SDKs that do not read `/flags?v=4`.

**Non-Goals:**

- Typed accessors (#104), a number and object event schema, custom exposure events, analysis queries, the config version 2 local evaluation algorithm, and wire changes.

## Decisions

### 1. The SDK sends the exposure, for config version 2 flags only

**Choice.** For config version 2 flags the SDK emits `$experiment_exposure` itself. Config version 1 flags keep the ingestion-derived exposure and never get a direct SDK exposure.

**Why.** Only the SDK sees which record supplied a read. Ingestion sees the event after the fact and has to guess from the value. Keeping config version 1 on the ingestion path avoids double counting and leaves running experiments untouched. `$feature_flag_config_version` 2 on `$feature_flag_called` is what tells ingestion not to copy the event, so it is required on every config version 2 flag-called event, including diagnostics.

**Alternative.** Teach ingestion to read the new properties and keep deriving exposures there. Rejected: ingestion would still depend on every SDK sending complete properties on `$feature_flag_called`, and it cannot apply a separate dedupe for exposures.

### 2. One trigger: a complete experiment split

**Choice.** A read emits the exposure only when the details that supplied its value have config version 2, reason code `experiment_split`, rule type `experiment`, a rule ID and a variant key, and the value was neither bootstrapped nor overridden.

**Why.** This is the one outcome that assigns an arm. A holdout, a paused experiment and a rollout exclusion all name the rule but assign no arm, so they are not exposures. Targeted and percentage matches have no arm at all.

The trigger does not look at whether an Experiment links to the rule, and ignores `has_experiment`. An Experiment links to its rule from the Experiment side, so an evaluator cannot tell whether one links to a given rule. A rule that no Experiment links to is a plain variant split; its exposures are cheap and nobody analyses them. Linking an Experiment to a running rule then needs no SDK change, and exposures recorded before the link are already there.

### 3. Decide from the evaluation details, not from the returned value

**Choice.** The decision and both events read the evaluation details that supplied the value. The value the read returned is not an input.

**Why.** The returned value can differ from the record. A typed read can return its caller default because the value is `null`, is `false` read as another type, or has another type. A legacy read renders number and object values as `true`. The user was still assigned the arm, and experiment analysis counts assignment. An arm whose value is `false` is still an arm.

### 4. Malformed splits fail closed

**Choice.** A split that lacks rule type `experiment`, a rule ID or a variant key emits no exposure. Its `$feature_flag_called` keeps config version 2 and reason code `experiment_split`, and omits the whole rule tuple. The SDK never fills a gap from the value, the flag key, a linked experiment or an earlier result.

**Why.** A wrong arm corrupts an experiment; a missing exposure only loses one data point. Keeping config version 2 on the diagnostic stops ingestion from deriving an exposure from it, and the reason code keeps the gap visible. A partial tuple would look like real attribution, so the event carries all of it or none of it. The contract's reader fixtures expect exactly this: the value stays usable and no exposure is emitted.

### 5. Attribution properties on `$feature_flag_called`

**Choice.** For config version 2 results, `$feature_flag_called` carries `$feature_flag_config_version`, `$feature_flag_reason_code`, and `$feature_flag_rule_id`, `$feature_flag_rule_type` and `$feature_flag_variant` when the reason code allows them. A per-reason table sets presence. Config version 1 events do not change.

**Why.**

- `$feature_flag_config_version` is separate from `$feature_flag_version`, which is the flag row's edit counter.
- `$feature_flag_reason_code` is the machine-readable code. `$feature_flag_reason` stays the human-readable description, so existing insights keep working.
- The table follows `rules/response_presence.json`. Rule fields come only from the record, and a field the table forbids is dropped even if a record carries it, so events stay valid against the public projection.
- No event carries an experiment ID: the evaluator cannot know which Experiment links to the rule. No event carries a holdout ID: a holdout belongs to its rule and is identified by rule ID plus the `holdout` reason. No event carries an assignment seed: seeds are evaluation inputs for local evaluation, not outcomes, and in events they would leak into analytics storage and exports.
- Config version 1 events stay byte-for-byte the same, so nothing that reads them today changes.

### 6. `$feature_flag_response` keeps the legacy rendering

**Choice.** Both events send the legacy rendering: `true` or `false` for booleans, the string for strings, `false` for `null`, `true` for numbers and objects. Never the caller default.

**Why.** The event schema accepts only a boolean or a non-empty string in `$feature_flag_response`, and #104 already fixes this rendering for typed reads. On the exposure the property is diagnostic only. The arm is `$feature_flag_variant`, which separates arms whose values are equal. A number and object event schema can come later without changing the trigger or the dedupe.

### 7. Dedupe: extend the flag-called key, add a separate exposure namespace

**Choice.**

- `$feature_flag_called` keeps its existing key, and for config version 2 results the key also includes the config version, rule ID and variant key, as sent on the event.
- `$experiment_exposure` has its own bounded namespace, keyed on the distinct ID, the canonical group context, the flag key, the config version, the rule ID and the variant key.
- If both events share one cache, the event name is part of the key, or the SDK checks and marks both entries in one atomic step.
- Bootstrapped and overridden values never reserve an exposure key.

**Why.**

- Without rule context, the flag-called key collapses distinct outcomes that share a value: two A/A arms, a holdout and an arm, two successive experiments, an experiment and the release rule that ships its winner. Including the config version also gives a flag that moves from config version 1 to 2 a fresh event.
- The exposure key leaves out the value: equal-valued arms are already separated by the variant key, and the legacy rendering of number and object values is not an identity.
- The exposure key leaves out the request ID, the evaluation time and the local or remote source. Otherwise a remote fallback after a local result, or a second request for the same user, would count one assignment twice.
- The reason code and rule type are not in either key. They add nothing within one rule ID for an exposure, which only exists for splits. For the flag-called key, the one collapse left is the same rule reporting two variant-less outcomes with the same value (for example holdout, then paused), which is rare and carries no arm.
- The exposure key always includes the distinct ID, even in client SDKs whose flag-called tracker leaves it out, because an exposure belongs to an identity.
- A shared cache without the event name lets the flag-called entry suppress the exposure written right after it, so the experiment loses its first exposure.

### 8. The feature flag event decision covers both events

**Choice.** The existing decision (per-read option, then the client-level default, then send) governs both events. A `false` decision emits neither event and touches neither dedupe namespace. There is no separate exposure option.

**Why.** Customers turn these events off to cut volume and noise. They would not expect a new event to appear from the same reads. A second option would double the configuration surface for one choice. A suppressed read must not reserve a key, for the same reason the existing event control gives: a later opted-in read would lose its events. The trade-off: a customer who turns events off for an experiment flag gets no exposures, exactly as today.

### 9. Bootstrap and client-side overrides

**Choice.** Bootstrapped and overridden values carry no attribution and never emit an exposure or reserve its key.

**Why.** A bootstrapped value has no reason or rule metadata; the bootstrap format carries only a value and a payload. It also often comes from an earlier evaluation in another process. An override is a value the developer chose, not an assignment. Not reserving the key means the real assignment is reported once the flags response replaces the bootstrapped value.

### 10. Minimal-event mode keeps the attribution

**Choice.** Minimal-event mode adds the attribution properties to its allowlist. It does not apply to `$experiment_exposure`.

**Why.** A config version 2 flag can report `has_experiment` false while an experiment rule assigns an arm, because nothing has linked an Experiment to the rule yet. Such an event can be minimized, and without the properties ingestion would copy it again and analysis would lose the rule context. Exposures are rare (one per assignment, after dedupe), so minimizing them saves little.

### 11. One best-effort step builds both events

**Choice.** One step takes the flag key, the evaluation details that supplied the value, and the read's context: provenance (bootstrap or override), local or remote source, request and error context, capture context, event settings and the event decision. It returns the events to capture and their dedupe keys. It never reads the returned value, definitions or other cached results. Capturing is best-effort: it never changes the returned value, never makes a read throw or reject, and never causes evaluation, network I/O or a flags reload.

**Why.** One step keeps both events consistent: the exposure always pairs with the flag-called event built from the same details. A wrapper that holds the same details, such as an OpenFeature provider hook, can call the step and produce the same events. Reads are on the request path, so analytics must never break them.

### 12. Local evaluation

**Choice.** An SDK that evaluates config version 2 flags locally produces the same details the flags service would and emits the same exposure, with `locally_evaluated` true. An SDK without that support gets those flags from remote evaluation. Config version 1 flags never get a direct exposure, local or remote.

**Why.** The exposure must not depend on where evaluation ran. The dedupe key leaves out the source, so a remote fallback after a local result for the same assignment is one exposure.

### 13. Relation to typed flag values (#104)

This change works whichever lands first.

- It does not use #104's accessor names, details object or reason vocabulary. It speaks of "reads that emit `$feature_flag_called`" and "the evaluation details that supplied the value", which cover typed accessors once they exist.
- #104's "Typed reads share the flag-called event" says a typed read uses "the existing" dedupe key and adds no properties, and leaves both to this change. Its intent is that a typed read and a legacy read of the same flag share one key. Whichever change archives second rewords that sentence to "the key a legacy read of the same flag uses", so it stays true once this change extends the key.
- #104 requires a typed read that returned its caller default to still report the assignment. Decision 3 does that.
- #104 fixes the legacy rendering in `$feature_flag_response` and gives bootstrapped and overridden values empty metadata. Decisions 6 and 9 agree.

## Risks / Trade-offs

- [An SDK forgets `$feature_flag_config_version` on a config version 2 flag-called event] → Ingestion copies it and the experiment double-counts. The attribution requirement makes the property mandatory, including on the malformed-split diagnostic.
- [SDKs that do not read `/flags?v=4` read config version 2 flags as legacy values] → They send no direct exposure and no config version, so ingestion keeps deriving exposures from string values, as today. Upgrading the SDK fixes it.
- [A customer turns flag events off and loses exposures] → Same as today for config version 1 flags; documentation says which reads to opt back in.
- [Bounded dedupe evicts an entry] → A later read can emit a duplicate exposure. Analysis takes the first exposure per person, so a duplicate adds volume, not bias.
- [A malformed split loses an exposure] → Only invalid producer output does this, and the diagnostic event makes it visible.

## Migration Plan

1. Review this change and settle the decisions.
2. Add the acceptance scenarios and the README index entry, then apply and archive in the same PR, as the repository requires.
3. SDKs implement against the archived spec. posthog-python is first; it stacks on posthog-python#1031.

## Open Questions

- When a number and object event schema exists, does `$feature_flag_response` on the exposure switch to the typed value, or does the exposure drop it?
- Should the flag-called key also include the reason code, to separate two variant-less outcomes of one rule that share a value?
- Should SDKs that persist their flag-called dedupe state across page loads (posthog-js browser) persist the exposure namespace the same way? This change allows it but does not require it.
