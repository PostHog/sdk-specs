## Why

`local-feature-flag-evaluator` says a group-aggregated condition buckets on "the selected group key" but never says what a group key *is*. The SDKs take group keys from an untyped map, so a caller passing a database id as a number is normal, and the flags service accepts it: `hashed_identifier` renders a JSON number by its decimal form (`Value::Number(n) => n.to_string()` in `rust/feature-flags/src/flags/flag_matching.rs`).

With nothing in the contract, SDKs diverged. PostHog/posthog-go#332 found that posthog-go asserted the key to a string unchecked and panicked on the caller's goroutine for every group-aggregated flag — including an ordinary capture with `SendFeatureFlags` — while its mixed-targeting path silently skipped the condition and answered `false`. posthog-python and posthog-node build the hash input with string formatting, so a numeric key happens to hash the same as the server there.

## What Changes

- Specify how a group key is rendered for bucketing: a string contributes its contents, a number its JSON encoding, matching the flags service.
- Require a group key the SDK cannot render that way to be treated as unresolved context — inconclusive and eligible for remote fallback — rather than crashing, and never to silently decide the flag.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: group key rendering for bucketing and the handling of unsupported group key types.

## Impact

Spec only. An SDK that already receives group keys as strings is unaffected.

## Non-goals

Does not change rollout or variant hashing itself, the selection of which group a condition uses, or how group *properties* are matched — property values already follow the backend-compatible stringification requirement.
