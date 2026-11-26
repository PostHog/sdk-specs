## Why

The spec says a flag dependency "evaluates with the same listing" of known-absent keys, but it never says which identity and properties the referenced flag is evaluated with. Some SDKs evaluated a referenced flag with the calling condition's properties and bucketing identifier. When a person-aggregated flag depended on a group-aggregated flag, the group flag then read person properties and hashed the distinct id. With known-absent keys, that produced a local `true` that the flags service would answer `false`, with no remote fallback.

The spec also scopes group known-absent keys to "the named group type" but doesn't say which group type a `type: "group"` filter without `group_type_index` belongs to. Older flag definitions use such filters. An SDK that skipped the listing for them read the supplied group value instead, so the listing no longer took precedence.

The flags service settles both. It evaluates flags in dependency order, each with the full request context, and a dependency filter only reads the stored result. `PropertyFilter::group_filter_index` resolves a group filter without an index to the condition's effective aggregation.

Found while reviewing PostHog/posthog-ruby#369.

## What Changes

- A referenced flag is evaluated as if it were evaluated directly with the same inputs, using its own aggregation, property context, bucketing identifier, and known-absent keys. The per-condition rules below apply to it unchanged.
- A `type: "group"` filter that omits `group_type_index` reads the group type of the condition's effective aggregation, including that group type's known-absent keys.
- A condition whose effective aggregation is a group type without a usable key doesn't match, and the remaining conditions still evaluate, as the flags service does. A flag is `false` only when no condition matches and none is inconclusive, so a person condition on a flag with flag-level group aggregation can still match. There is no flag-level `false` rule. A supplied group key without the needed group properties stays inconclusive.
- A usable group key is a non-empty string or a number, as in the flags service. An empty string, null, a boolean, an array or an object counts as no key.
- A flag with a holdout above 0% whose flag-level group has no usable key is inconclusive with `missing_context`, because the flags service hashes an empty identifier for the holdout and may return `holdout-<id>`.
- The evaluate-flags `missing_context` reason covers a missing or unusable group key only for such a holdout.
- Acceptance scenarios cover a dependency on a flag with another aggregation (matching and not matching), a dependency whose only condition needs a missing group key, a person condition on a flag whose flag-level group is missing (directly and as a dependency), the holdout case, a group filter without an index (inheriting the flag-level aggregation and following a condition-level aggregation), and usable and unusable group keys. Non-string group keys are tagged `@json_group_keys_capable`.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: the per-condition aggregation and flag-dependency requirements, the canonical scenario for missing group context, and the group key rendering requirement.
- `evaluate-flags`: the `missing_context` unresolved reason in snapshot unresolved flag reporting.

## Impact

SDKs that evaluate a referenced flag with the caller's context need a change. This also changes results without known-absent keys: a cross-aggregation dependency now resolves locally to the value `/flags` returns, instead of reading the wrong properties. SDKs that ignored known-absent keys for a group filter without an index need a one-line change. SDKs that returned inconclusive for a group flag evaluated without its group key now return `false`, unless a holdout needs the key. SDKs that return `false` from the flag-level aggregation before checking conditions (for example posthog-js) need to skip per condition instead. Elixir on main returns `missing_context` for a flag without its group key; PostHog/posthog-elixir#261 changes it.

## Non-goals

No change to how a dependency filter compares values, to cycle and missing-definition handling, or to the remote fallback for an unresolved dependency.
