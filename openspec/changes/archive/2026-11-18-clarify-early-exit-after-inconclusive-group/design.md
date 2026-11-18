## Context

The current rule says the evaluator "SHALL return `false` immediately" on an `early_exit` rollout exclusion, and separately that an inconclusive group "SHALL also not itself trigger `early_exit`". Neither sentence covers an exclusion that comes after an inconclusive group.

Pinned sources:

- [Flags service](https://github.com/PostHog/posthog/blob/8cd8ede50cd1/rust/feature-flags/src/flags/flag_matching.rs#L2088-L2115): on an `early_exit` exclusion it stops. It returns an error when an earlier condition could not be resolved (`no_match_error`), and `false` otherwise.
- [Python](https://github.com/PostHog/posthog-python/blob/7c87c8ea1528/posthog/feature_flags.py#L639-L643): returns `_unmatched_flag_result(inconclusive_reason)`.
- [Go](https://github.com/PostHog/posthog-go/blob/f0d303eb10cb/featureflags.go#L1793-L1798): returns `errInconclusiveMatch` when an inconclusive reason is set, `false` otherwise.
- [Node](https://github.com/PostHog/posthog-js/blob/dc70646a7b6b/packages/node/src/extensions/feature-flags/feature-flags.ts#L683-L691): `break`s when an inconclusive reason is set, so the post-loop check reports inconclusive.
- [Ruby](https://github.com/PostHog/posthog-ruby/blob/cd4e96e047c1/lib/posthog/feature_flags.rb#L1518): `break if early_exit`, then the post-loop check reports inconclusive.
- [PHP](https://github.com/PostHog/posthog-php/blob/eeab107fb704/lib/FeatureFlag.php#L1377-L1389): `break`s when an inconclusive reason is set, `false` otherwise.
- [.NET](https://github.com/PostHog/posthog-dotnet/blob/e0155d4ccaa7/src/PostHog/Features/LocalEvaluator.cs#L472-L479): throws `InconclusiveMatchException` when an inconclusive reason is set, `false` otherwise.
- [Elixir](https://github.com/PostHog/posthog-elixir/blob/130aedd3f1c6/lib/posthog/feature_flags/local_evaluator.ex#L404-L418) diverges: it exits early only when no reason is set (`is_nil(reason)`), and otherwise keeps evaluating later groups.
- [Rust](https://github.com/PostHog/posthog-rs/pull/373) diverges on `main` the same way (`early_exit && !is_inconclusive`). PR #373 aligns it.

## Goals / Non-Goals

**Goals:** State the behavior the service and most SDKs already share, so the remaining SDKs can be aligned and tested.

**Non-Goals:** Change when a group counts as inconclusive, change unresolved-reason precedence, or change behavior when `early_exit` is disabled.

## Decisions

1. An `early_exit` exclusion always ends evaluation. Every filter in that group matched, so no value of the missing context lets a later group decide the flag. Continuing can only return a value the service would not.
2. A prior inconclusive group wins over the exclusion's `false`. That group might have matched with full context, so the local evaluator cannot give a definitive answer, and remote fallback stays available. This is the existing "remains inconclusive" rule applied at the point of exit.
3. Edit the existing requirement instead of adding a new one, because `early_exit` and inconclusive handling are already defined there.

## Validation

The new scenario reuses the wording of the neighbouring `early_exit` and inconclusive scenarios. Run strict OpenSpec validation before and after archive, and `git diff --check`. These checks validate the specification, not cross-SDK conformance.

## Risks / Trade-offs

- SDKs that currently continue past the exclusion (Elixir, Rust before #373) will return inconclusive where they returned a later group's value. Those values disagreed with the service, and inconclusive falls back to it.
