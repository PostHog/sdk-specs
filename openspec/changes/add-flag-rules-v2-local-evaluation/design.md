## Context

A server SDK with local evaluation polls `GET /flags/definitions` (or `/api/feature_flag/local_evaluation`) and evaluates flags in process. The feed it gets today leaves every config version 2 flag out, and leaves out a config version 1 flag that depends on one. Two things follow:

- The SDK reads a config version 2 flag remotely on a single read, and leaves it out of bulk and local-only reads.
- Today's evaluators were never written for config version 2. A config version 2 document has no `groups`, so a config version 1 evaluator that receives one loops over zero conditions and returns `false` as a local result, with no fallback. In some SDKs that local `false` also stops a remote result from replacing it in a bulk read. The legacy feed's omission is what protects every released SDK.

The flags service is adding a second feed for exactly `v=2` ([PostHog/posthog#135503](https://github.com/PostHog/posthog/pull/135503) builds it, [PostHog/posthog#135515](https://github.com/PostHog/posthog/pull/135515) serves it):

- It is the legacy body plus one entry per valid config version 2 flag, inactive ones included, with its own ETag.
- For a project without config version 2 flags the service answers `v=2` from the legacy entry, so the body and ETag are the ones the SDK gets today.
- Every other `v`, a repeated `v` and no `v` keep the legacy feed. A service without the change ignores `v`.

The public rules v2 contract (`contracts/feature_flag_rules_v2` in posthog-sdk-test-harness) defines what an evaluator does. This change reads contract 10.1.0 as released in [posthog-sdk-test-harness 1.36.0](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.36.0). Harness 1.35.0 also reports contract 10.1.0 but lacks the local evaluation files, so the harness release is the reference.

- The config schema, the literal registry and its version rule, the boolean (135 cases), value (49) and experiment (73) corpora, and the hash vectors.
- Added by [posthog-sdk-test-harness#111](https://github.com/PostHog/posthog-sdk-test-harness/pull/111) in harness 1.36.0:
  - `rules/local_outcomes.json` maps each case's expected status to a local outcome (`conclusive`, `inconclusive` with an unresolved reason, or `not_applicable`).
  - `corpus/v2_local_evaluation.json` adds six `flag_disabled` cases and two ordered missing-context cases.
  - `fixtures/wire/definitions_feed.json` is one whole feed of twelve entries with the outcome of each.

This change turns the contract into SDK behavior: when to ask for the feed, what to do with each entry and each outcome, what the local record looks like, and how it reaches the getters, snapshots and events. The acceptance feature reuses the contract's fixture and cases, so a reviewer can check each expectation against the contract.

The existing specs this change builds on:

- `local-feature-flag-evaluator`: inconclusive results and remote fallback, and the config version 1 rules this change scopes.
- `flag-definition-loader`: "External flag definition cache providers" and "Definition snapshots retain the property matching version".
- `evaluate-flags`: the single fallback request, "Snapshot unresolved flag reporting" and "Snapshot reads report experiment exposure".
- `feature-flag-called-tracker`: "Config version 2 attribution on `$feature_flag_called`" and "Flag definition identity on flag-called events".
- `experiment-exposure`: "Locally evaluated results".

## Goals / Non-Goals

**Goals:**

- A local result for a config version 2 flag equals the flags service's result for the same inputs, or there is no local result.
- Nothing changes for config version 1 flags, for SDKs that do not ask for the new feed, or for projects without config version 2 flags.
- A fleet of mixed SDK releases on one shared definition cache stays safe.
- A local evaluation feature and experiment exposure scenarios that the harness can run once it binds four new steps.

**Non-Goals:**

- Group, cohort and flag-dependency targeting in config version 2 documents.
- The project's timezone in the feed.
- Typed accessors (#104), and any change to `/flags`, the event schemas or bootstrap.

## Decisions

### 1. Only a complete implementation asks for the feed, and it always does

**Choice.** An SDK sends `v=2` on every definitions request when it meets the whole capability and also reads `/flags?v=4` records and sends the config version 2 events. Otherwise it sends no `v`. There is no option to turn the request off or on.

**Why.**

- The request is what admits an SDK to config version 2 documents. An SDK with a partial implementation would return wrong values or send events without attribution.
- The events need the `/flags?v=4` reader: a fallback for a config version 2 flag must return a record with its reason and rule, or its `$feature_flag_called` loses the attribution that keeps ingestion from deriving a second exposure.
- For a project without config version 2 flags the response is byte-identical, and a server without the new feed ignores the parameter, so the default changes nothing there.

**Alternative.** An opt-in option. Rejected: the default is safe, and an option adds a configuration to test for no gain. Rolling back an SDK release means restoring the unversioned request.

### 2. `filters.version` selects the evaluator on every path

**Choice.** The contract's version rule chooses the evaluator: absent or `1` is config version 1, a number equal to `2` is config version 2, and anything else is unsupported. This holds on every path, including the evaluation of a dependency. A config version 1 flag that depends on a flag of another version is inconclusive with `unsupported_definition`, active or not.

**Why.**

- Dependency evaluation bypasses the main entry point in the SDKs we read, so the dispatch must be on that path too, or a config version 2 document reaches the config version 1 rules there.
- The flags service never sends a config version 1 flag that depends on a config version 2 flag: writes reject such a dependency, and both feeds leave out a dependent of a flag they leave out. Treating it as a dependency with no loaded definition keeps today's outcome for a case that should not occur.
- Requiring the same of SDKs without this capability is cheap and makes a misrouted document fall back instead of returning `false`.

**Alternative.** Evaluate the config version 2 target and compare its value with the config version 1 dependency rules. Rejected for now: it defines cross-version semantics for a case that the service never produces. Flag predicates in config version 2 documents arrive later with their own corpus cases.

### 3. A closed parser, and group, cohort and flag targeting stay unsupported

**Choice.** The parser accepts exactly what the contract's config schema, registry and semantic constraints accept, ignores the presentation fields (`description`, `metadata`, `label`), and marks every other document unsupported as a whole. Group aggregation and group, cohort and flag predicates are unsupported until the contract adds their evaluation.

**Why.**

- A newer document can change the meaning of rules an older parser recognises. The contract's feed fixture puts the unknown part in a second rule, after a first rule that matches, so a parser that evaluates as it goes returns a value where it must fall back.
- The contract's corpora contain only person predicates today. A released SDK that rejects group, cohort and flag targeting falls back to the flags service, so those can open remotely first and locally once the corpus covers them.

### 4. Ordered evaluation with a partial property map

**Choice.** Rules and predicates are checked in stored order. The first predicate that misses ends its rule. The first predicate that cannot be decided ends the evaluation as inconclusive. The SDK always evaluates with a partial property map. Explicit exact matching follows the snapshot's `property_matching_version`.

**Why.**

- An earlier matching rule is terminal. Config version 1 local evaluators skip an undecidable condition and try the next one, which is safe only because conditions there are alternatives; for ordered rules it can return a later rule's value where the flags service returns an earlier one's. The contract's `context` cases pin this.
- The order inside a rule is the flags service's order. Checking every predicate first could turn some fallbacks into local misses, but then SDKs would differ on which reads reach `/flags`.
- A caller's map is partial by nature: the SDK cannot know that a key is absent rather than unsent. The contract's cases with a complete map stay in the in-process replay.
- The known-absence input of `local-feature-flag-evaluator` lists keys that the caller knows are absent. The contract has no such input yet, so a listed key cannot be decided here either, and the SDK does not read a value supplied for it. The fallback carries the listing, so the flags service decides with the same inputs, and a local result never disagrees with it.

### 5. Each outcome uses an existing path

**Choice.**

| Contract outcome | SDK path | Unresolved reason |
| --- | --- | --- |
| `success` | Local record | none |
| `missing_context`, `invalid_property` | Fallback in auto mode, unresolved in local-only mode | `missing_context` |
| `invalid_regex`, `parse_error` (`malformed`, `unsupported`) | Fallback in auto mode, unresolved in local-only mode | `unsupported_definition` |

The reason is the cause that ended the evaluation. The SDK never substitutes `false`, the default value, an empty value or a later rule's value, and a failed fallback stays a failed remote evaluation.

**Why.**

- Both reasons already exist in `evaluate-flags`, and their definitions fit: `missing_context` covers "supplied it in a form the evaluator cannot use", and `unsupported_definition` covers "a malformed value".
- An invalid regular expression belongs to the definition, and regex engines differ between languages, so the SDK cannot tell a pattern that is invalid everywhere from one that only its engine rejects.
- The existing precedence list (`experience_continuity`, `unsupported_definition`, `unresolved_dependency`, `missing_context`) exists because config version 1 conditions have no order. Here one cause ends the evaluation. The parser runs first, so an unsupported document always reports `unsupported_definition`.

### 6. An inactive flag is `null` with `flag_disabled`, even when its document is unsupported

**Choice.** For `active: false`, the result is conclusive before any rule is read: value `null`, reason code `flag_disabled`, config version 2, no rule. Legacy getters render `false` with no payload, and a typed read returns the caller's default.

**Why.**

- `null` renders as `false` in the legacy getters, which is what an inactive config version 1 flag returns locally. A typed read gets the caller's default, as for a flag the flags service leaves out.
- An inactive flag is off whatever its document says. The flags service omits it, so a fallback cannot return a value for it, and both reference SDKs check `active` before anything else today.

Contract 10.1.0 pins `flag_disabled` with `null` for supported documents. It does not pin the unsupported case; task 2.3 adds it.

**Alternatives.** `false` for every return type: a typed string read would then report a type mismatch. The flag's default value: an inactive flag with default `true` would be on.

### 7. The local result is a `/flags?v=4` record

**Choice.** A conclusive local result is held as the record that a `/flags?v=4` response carries: value, reason code and rule index, config version 2, rule ID and rule type when the reason names a rule, variant key for a split, and the definition's ID, version and `has_experiment`. Legacy getters render it as they render a remote record.

**Why.** The getters, snapshots and the event step already handle that record. With one shape, the local path changes nothing downstream, and the events that `feature-flag-called-tracker` and `experiment-exposure` define follow with `locally_evaluated` true. The exposure's dedupe key leaves out the source, so a remote fallback that repeats a local assignment is not a second exposure.

### 8. Dates in UTC

**Choice.** A date or date-time without an offset, and the current time for a relative date, are read in UTC. The SDK passes UTC to the evaluator, never the host's timezone.

**Why.** The flags service reads these values in the project's timezone, and neither definitions feed carries it. UTC is what config version 1 local evaluation uses without a project timezone, and it is the same on every host, so two SDK processes agree with each other. In a project that is not on UTC, local and remote results can differ for a person whose date lies within the UTC offset of a boundary, as they can for config version 1 flags today.

**Alternative.** Add the project timezone to the feed and fall back for naive and relative dates until an SDK has it. Deferred: relative dates are the common case, so most date filters would fall back. The feed can gain an optional timezone field later.

### 9. The shared cache field `flags_v2`

**Choice.** In data handed to a definition cache provider or another definition store, `flags` keeps config version 1 entries only. Every other entry goes to `flags_v2`, in feed order. A reader loads both and dispatches each entry on its own `filters.version`.

**Why.**

- Several SDK releases can share one cache. An older release reads only `flags`, so it never sees a config version 2 document. That is why a config version 3 entry goes to `flags_v2` as well.
- A provider that drops unknown fields loses only the config version 2 flags, which then fall back.
- The name follows the existing snake_case fields and the feed it comes from.

**Alternatives.** `versioned_flags`, `flags_config_v2`. Rejected: `flags_v2` says what the field holds and sits next to `flags`.

### 10. The harness capability `feature_flags_local_evaluation_v2`

**Choice.** The capability follows the harness's `feature_flags_local_evaluation_v1`, and its suffix is the definitions feed version the SDK requests, as `flags_response_v4` names `/flags?v=4`. An SDK declares it only in a release that requests `v=2`, after the in-process replay and the black-box suite pass. The in-process replay covers the cases that a public API cannot reach: complete property maps and the white-box hash cases.

**Alternative.** `flag_rules_v2`. Rejected: it is shorter but does not say "local", although remote-only SDKs also read rules v2 results.

### 11. Unknown entry fields are ignored

**Choice.** The closed parser covers `filters`. An unknown top-level field, or an unknown entry field outside `filters`, is ignored.

**Why.** Entry fields outside `filters` describe the row, not its rules. Rejecting a flag for one would turn a harmless addition on the server into a fallback in every released SDK. Contract 10.1.0 does not pin this. Its definitions entry schema is closed, but that schema checks what the flags service sends, not what a reader does with it. Task 2.3 adds a feed entry.

## Acceptance features

`acceptance/private/flag-rules-v2-local-evaluation.feature` is black-box: it serves typed definitions, calls public getters and evaluated snapshots, flushes, and checks received events and `/flags` traffic. Most of its steps are bound today. It needs four new bindings, which the harness's local evaluation suite adds; the feature's header comment names each step and what it does. One is a local evaluation setup that allows `/flags` requests: the harness's native local evaluation setup fails a scenario that sends one, and the fallback scenarios must.

The scenarios keep the legacy `@server` tag and add `@requires:feature_flags_local_evaluation_v2`. They move to `@sdk:server` once the steps are bound and a real SDK adapter passes them.

The shared-cache scenarios in `flag-definition-loader.feature` use that feature's own phrasing. The harness cannot run any scenario of that feature yet, because most of its steps are unbound, so these scenarios also wait for those bindings.

## Risks / Trade-offs

- [An SDK ports the evaluator from prose and differs from the flags service] → The corpora are the definition. The SDK replays them in process, and the black-box suite runs the mixed feed. The contract still leaves some behaviors of the flags service unpinned (some date and semantic-version forms, very large regular expressions). An SDK declines what it cannot reproduce and falls back.
- [A project not on UTC sees local and remote date results differ near a boundary] → Accepted, as for config version 1 flags; an optional timezone field can follow.
- [Group, cohort and dependency flags always fall back] → One `/flags` request per single read for such a flag, as today. They become local when the contract covers them.
- [An SDK requests `v=2` before its evaluator is complete] → Decision 1, and the capability is declared only with the request, after both suites pass.
- [A shared cache provider drops `flags_v2`] → Only config version 2 flags are lost locally; they fall back.

## Migration Plan

1. Review this change and settle the decisions, above all the two names.
2. Done: contract 10.1.0 shipped in harness 1.36.0 with posthog-sdk-test-harness#111, and this change points at it. A later contract release pins decisions 6 and 11 (task 2.3).
3. The harness binds the four steps and adds the suite behind `feature_flags_local_evaluation_v2`.
4. Apply and archive this change in this PR, as the repository requires.
5. SDKs implement in three releases: the evaluator with the in-process replay, which nothing calls; the dispatch and the cache field, inert because no config version 2 document arrives yet; then the `v=2` request and the capability. posthog-python first, then posthog-node.
6. Rollback of an SDK release: restore the unversioned request.

## Open Questions

- When the contract pins decisions 6 and 11 (task 2.3).
- A config version 1 flag that depends on a config version 2 flag (decision 2): unsupported locally here. Should it instead evaluate the target once the contract has cases for it?
- The project's timezone in the feed (decision 8): when to add it.
- Known-absent keys (decision 4): they fall back here. Should a listed key instead be read as absent, as the contract's complete-map cases read a missing key, once the contract has cases for it?
