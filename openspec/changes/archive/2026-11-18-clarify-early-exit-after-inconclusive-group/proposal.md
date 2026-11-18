## Why

The `early_exit` rule says the evaluator returns `false` immediately when a group's filters match but its rollout excludes the user. It doesn't say what happens when an earlier group was inconclusive. Read literally, the evaluator returns a definitive `false` even though the inconclusive group might have matched. The flags service and six server SDKs do something else: they stop evaluating at the exclusion and keep the earlier inconclusive result, so the caller can fall back to remote evaluation. posthog-elixir and posthog-rs before [PostHog/posthog-rs#373](https://github.com/PostHog/posthog-rs/pull/373) skip the early exit instead and keep checking later groups, which can return a later group's value.

## What Changes

- With `early_exit` enabled, a rollout exclusion always ends condition evaluation. Later groups are not evaluated, even after an earlier inconclusive group.
- If an earlier group was inconclusive, the result is inconclusive rather than `false`.
- Add an acceptance scenario for an inconclusive group, then an `early_exit` exclusion, then a catch-all that would otherwise match.
- Sync the canonical local-evaluator specification and archive this change on the same branch.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: `early_exit` handling after an earlier inconclusive condition group.

## Impact

This clarifies an existing rule to match the flags service and the shipped Python, Go, Node, Ruby, PHP and .NET evaluators. posthog-elixir needs a separate SDK change. posthog-rs is being aligned in [PostHog/posthog-rs#373](https://github.com/PostHog/posthog-rs/pull/373).

No SDK implementation, public method, request schema, dependency, or release artifact changes in this repository.
