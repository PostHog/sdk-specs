## Why

Flags with config version 2 ("flag rules v2") are built from ordered rules. Today SDKs never evaluate them locally: the definitions feed for local evaluation leaves them out, so a server SDK fetches each one from `/flags` on a single read and leaves it out of bulk and local-only reads.

The definitions endpoint is gaining a second feed, selected by `v=2`, that carries config version 1 and 2 flags side by side ([PostHog/posthog#135503](https://github.com/PostHog/posthog/pull/135503), [PostHog/posthog#135515](https://github.com/PostHog/posthog/pull/135515)). The public rules v2 contract already defines the config schema, the evaluation corpora and the hash vectors (`contracts/feature_flag_rules_v2` in posthog-sdk-test-harness). Contract 10.1.0, released in [posthog-sdk-test-harness 1.36.0](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.36.0), adds what a local evaluator does with every corpus case, cases for inactive flags and for missing context, and a fixture of a whole mixed feed ([posthog-sdk-test-harness#111](https://github.com/PostHog/posthog-sdk-test-harness/pull/111)).

No spec says when an SDK may ask for the new feed, what it does with an entry it cannot read, or how a local result reaches the getters and the events. An SDK that gets this wrong returns a wrong value silently: today's evaluators read a config version 2 document as a flag with no conditions and return `false` as a local result, with no fallback.

`experiment-exposure` already requires that a locally evaluated split sends the same exposure with `locally_evaluated` true. Its acceptance scenarios for that carry a tag that no runner implements.

## What Changes

- A new capability, `flag-rules-v2-local-evaluation`:
  - Only an SDK that meets the whole capability, reads `/flags?v=4` records and sends the config version 2 events requests definitions with `v=2`. It does so on every definitions request, with no option. Every other SDK sends no `v`.
  - The feed is read like the legacy feed. A legacy body is a complete version 2 feed, and an unsupported entry never rejects the feed or another entry.
  - A closed parser reads each config version 2 document once. Anything the contract does not define makes the whole flag unsupported. Group, cohort and flag targeting are unsupported until the contract defines their evaluation.
  - Rules and their predicates are evaluated in stored order. The first predicate the SDK cannot decide ends the evaluation; it never skips to a later rule. The caller's property map is partial, so a key it did not supply cannot be decided.
  - Each outcome uses an existing path: a conclusive local record; for an undecided or unsupported flag, remote fallback in auto mode and an unresolved flag (`missing_context` or `unsupported_definition`) in local-only mode. Never `false`, the default value, or a later rule's value.
  - An inactive flag is a conclusive `null` with the reason code `flag_disabled`, whatever its document says. Legacy getters render it as `false`.
  - The local result is the record a `/flags?v=4` response carries, so getters, snapshots and both events treat it like a remote record, with `locally_evaluated` true.
  - Dates without an offset, and relative dates, are read in UTC.
  - The harness capability `feature_flags_local_evaluation_v2` is declared only in a release that requests `v=2`, after an in-process corpus replay and the black-box suite pass.
- `local-feature-flag-evaluator`: `filters.version` selects the evaluator on every path, the flag-dependency path included. A version other than absent, `1` or `2` is unsupported, and a config version 1 flag that depends on a flag of another version is inconclusive.
- `flag-definition-loader`: the shared definition cache keeps config version 1 entries in `flags` and every other entry in a new field, `flags_v2`, so an older SDK on the same cache never reads a config version 2 document.
- Acceptance: a new `acceptance/private/flag-rules-v2-local-evaluation.feature` built on the contract's mixed-feed fixture and local cases; the two local scenarios of `experiment-exposure.feature` rewritten with concrete definitions and `@requires:feature_flags_local_evaluation_v2`; shared-cache scenarios in `flag-definition-loader.feature`.

No breaking change. Config version 1 flags, their evaluator and their events do not change, and an SDK that does not request `v=2` sees no difference.

## Capabilities

### New Capabilities

- `flag-rules-v2-local-evaluation`: when an SDK requests the version 2 definitions feed, how it parses and evaluates config version 2 flags, how each local outcome maps to the existing fallback paths, the local record and its events, dates, and the harness capability.

### Modified Capabilities

- `local-feature-flag-evaluator`: the config version selects the evaluator on every path, including flag dependencies.
- `flag-definition-loader`: the `flags_v2` field of shared definition caches.

## Impact

- Specs and acceptance features only. No SDK code changes in this repository.
- posthog-python is first: its config version 2 evaluator is a draft that nothing calls yet ([PostHog/posthog-python#1250](https://github.com/PostHog/posthog-python/pull/1250)). The dispatch on `filters.version` and the cache field follow, and the `v=2` request comes last, in its own release. posthog-node follows the same steps.
- posthog-sdk-test-harness binds three new steps and adds the black-box suite behind `feature_flags_local_evaluation_v2`: the mock serves a separate definitions document for `v=2` requests and records the query.
- No change to the `/flags` contract, the event schemas or the bootstrap format.

## Out of scope

- Group aggregation, cohort predicates and flag predicates in config version 2 documents. They stay unsupported locally until the contract adds their evaluation.
- The project's timezone in the definitions feed.
- Typed flag accessors ([PostHog/sdk-specs#104](https://github.com/PostHog/sdk-specs/pull/104)). This change only says that a typed read of an inactive flag returns the caller's default.
- SDKs other than posthog-python and posthog-node; each ports the contract corpora on its own schedule.
