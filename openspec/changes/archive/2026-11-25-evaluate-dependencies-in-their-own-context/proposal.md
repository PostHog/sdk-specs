## Why

The spec says a flag dependency "evaluates with the same listing" of known-absent keys, but it never says which identity and properties the referenced flag is evaluated with. Some SDKs evaluated a referenced flag with the calling condition's properties and bucketing identifier. When a person-aggregated flag depended on a group-aggregated flag, the group flag then read person properties and hashed the distinct id. With known-absent keys, that produced a local `true` that the flags service would answer `false`, with no remote fallback.

The spec also scopes group known-absent keys to "the named group type" but doesn't say which group type a `type: "group"` filter without `group_type_index` belongs to. Older flag definitions use such filters. An SDK that skipped the listing for them read the supplied group value instead, so the listing no longer took precedence.

The flags service settles both. It evaluates flags in dependency order, each with the full request context, and a dependency filter only reads the stored result. `PropertyFilter::group_filter_index` resolves a group filter without an index to the condition's effective aggregation.

Found while reviewing PostHog/posthog-ruby#369.

## What Changes

- A referenced flag is evaluated as if it were evaluated directly with the same inputs, using its own aggregation, property context, bucketing identifier, and known-absent keys. A group-aggregated referenced flag whose group is not supplied resolves as `false`.
- A `type: "group"` filter that omits `group_type_index` reads the group type of the condition's effective aggregation, including that group type's known-absent keys.
- Acceptance scenarios cover a dependency on a flag with another aggregation, a group dependency without its group, and a group filter without an index.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: the per-condition aggregation and flag-dependency requirements.

## Impact

SDKs that evaluate a referenced flag with the caller's context need a change. This also changes results without known-absent keys: a cross-aggregation dependency now resolves locally to the value `/flags` returns, instead of reading the wrong properties. SDKs that ignored known-absent keys for a group filter without an index need a one-line change.

## Non-goals

No change to how a dependency filter compares values, to cycle and missing-definition handling, or to the remote fallback for an unresolved dependency.
