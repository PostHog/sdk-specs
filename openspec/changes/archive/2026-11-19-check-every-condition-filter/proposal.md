## Why

`local-feature-flag-evaluator` says all filters within one condition group are combined with logical AND, and it says when a single criterion is inconclusive. It does not say what the condition does when one filter is inconclusive and another definitively fails. Read as a short-circuit, the evaluator stops at the first filter it cannot check and defers the flag, even though a later ANDed filter already rules the condition out.

Every shipped server evaluator checks the remaining filters instead, and each one carries the same comment: "Filters in a condition have no defined order, so an inconclusive filter does not stop the loop."

- posthog-rs `1b623afa3dde` ([PostHog/posthog-rs#384](https://github.com/PostHog/posthog-rs/pull/384)) is the SDK that just moved: it stopped at the first unresolvable filter and returned inconclusive where the other SDKs return no match. Rerunning the generated comparison from [PostHog/posthog-rs#373](https://github.com/PostHog/posthog-rs/pull/373) against posthog-python, this was the only remaining difference — 83 of 7,200 evaluated pairs — and the change brings it to zero.
- posthog-python, posthog-go, posthog-node, posthog-ruby, posthog-php, posthog-dotnet and posthog-elixir already behave this way.

Deferring a condition that is already ruled out costs a `/flags` request the SDK could have answered locally, and under local-only evaluation it returns no value at all.

## What Changes

- Add an **Every filter in a condition is checked** requirement to `local-feature-flag-evaluator`: an inconclusive filter does not stop the condition; a filter that definitively does not match makes the whole condition a definitive no-match; a condition is inconclusive only when nothing in it definitively failed.
- Record that such a condition behaves like any other mismatch — evaluation continues with the next condition group, and the flag can still resolve definitively.
- Add acceptance scenarios for the ruled-out condition, the still-inconclusive condition, and a ruled-out condition that leaves the flag definitively false when no later condition matches.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: one added requirement. Existing requirements, including **Condition groups are selected as ordered alternatives** and the criterion-level result model, are unchanged.

## Impact

- Descriptive of shipped behavior in posthog-python, posthog-go, posthog-node, posthog-ruby, posthog-php, posthog-dotnet, posthog-elixir and posthog-rs. No SDK is known to diverge.
- No SDK implementation, public method, request schema, dependency, or release artifact changes in this repository.
- Deliberately unspecified: which inconclusive filter supplies a "requires server evaluation" outcome when several are unresolvable. Seven SDKs take it from the first unresolvable filter; posthog-elixir takes it from any. The requirement states the reason precedence that is already specified and leaves this selection to the SDKs.
