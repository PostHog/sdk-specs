## Context

The spec defines the result state of one criterion and the AND of filters within a group, but not the order in which a group's filters are resolved when some of them cannot be checked from partial caller-supplied context.

Pinned sources, all carrying the same loop shape — collect the inconclusive reason and continue, return no match as soon as a filter definitively fails, report inconclusive only after the loop:

- [Python](https://github.com/PostHog/posthog-python/blob/5994ff313c6d/posthog/feature_flags.py#L886-L925)
- [Go](https://github.com/PostHog/posthog-go/blob/f0916de8da9a/featureflags.go#L1864-L1908)
- [Node](https://github.com/PostHog/posthog-js/blob/04b89402b336/packages/node/src/extensions/feature-flags/feature-flags.ts#L767-L830)
- [Ruby](https://github.com/PostHog/posthog-ruby/blob/d6d1efcb30f9/lib/posthog/feature_flags.rb#L1570-L1608)
- [PHP](https://github.com/PostHog/posthog-php/blob/03b635f91a65/lib/FeatureFlag.php#L1439-L1490)
- [.NET](https://github.com/PostHog/posthog-dotnet/blob/883a6e4bbf0f/src/PostHog/Features/LocalEvaluator.cs#L544-L607)
- [Elixir](https://github.com/PostHog/posthog-elixir/blob/e2f134777f77/lib/posthog/feature_flags/local_evaluator.ex#L593-L615)
- [Rust](https://github.com/PostHog/posthog-rs/blob/eaeeff8c5adf/src/feature_flags.rs#L893-L909), aligned by [PostHog/posthog-rs#384](https://github.com/PostHog/posthog-rs/pull/384)

The flags service is not a tiebreaker here. It evaluates with authoritative stored properties, so it has no inconclusive state: it short-circuits on the first filter that does not match. The rule below only decides whether an SDK with partial context defers or answers, and it never answers where the service would disagree: the filters are ANDed, so a condition with one failing filter cannot match whatever the unresolved filter turns out to be.

## Goals / Non-Goals

**Goals:** State the filter-level rule the eight server evaluators share, so partial context defers only when deferral can change the answer.

**Non-Goals:** Change when a single criterion is inconclusive, change unresolved-reason precedence, change group-level ordering or `early_exit`, or specify which unresolvable filter supplies a "requires server evaluation" outcome.

## Decisions

1. A definitive no-match anywhere in the condition wins over an earlier inconclusive filter. The condition is an AND, so the unresolved filter cannot rescue it.
2. A ruled-out condition is an ordinary mismatch: evaluation continues with the next group, the earlier inconclusive reason does not survive the condition, and the flag can still resolve definitively. This keeps the rule consistent with "a group that does not match SHALL NOT prevent evaluation of the next group".
3. Add a requirement rather than editing **Condition groups are selected as ordered alternatives**, which is about ordering between groups, not within one.
4. Leave the "requires server evaluation" selection open. Seven SDKs keep the outcome of the first unresolvable filter and posthog-elixir merges it from any; the difference only changes which remote-fallback signal is reported, not the local result, and no backend behavior settles it.

## Validation

The new scenarios reuse the wording of the neighbouring condition scenarios in the spec and in `acceptance/private/local-feature-flag-evaluator.feature`. The `openspec` CLI is not available in this environment, so strict validation was not run; the delta follows the structure of the archived changes alongside it. These checks validate the specification, not cross-SDK conformance.

## Risks / Trade-offs

- Low. Every audited SDK already behaves this way, so the requirement records behavior rather than asking for a change.
- An SDK that short-circuits on the first inconclusive filter will now report a definitive `false` where it used to defer. That removes a `/flags` request whose answer was already determined locally.
