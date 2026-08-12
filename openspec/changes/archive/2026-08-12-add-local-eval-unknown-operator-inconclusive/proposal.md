## Why

The prior `add-local-eval-string-operators` change (archived 2026-08-07) flagged a follow-up
(`tasks.md` §4.2) that it deliberately left out: posthog-dotnet's PR for the same feature
additionally changed how an *unrecognized* property-filter operator is handled — degrading only
the affected flag to inconclusive/remote-evaluation instead of throwing and disabling local
evaluation for the entire project. That change kept the item out because only one SDK was
confirmed to implement it.

This run found a second, independent confirmation:
[posthog-php#209](https://github.com/PostHog/posthog-php/pull/209) ("Add starts_with/ends_with
operators to local evaluation") makes the same change in `FeatureFlag::matchProperty` — the
previous unconditional `return false` fallback for any unrecognized operator was replaced with
`throw new InconclusiveMatchException("Unknown operator: " . $operator)`, which the SDK's
evaluation loop catches per-flag and treats as "defer this flag to remote evaluation," leaving
other flags' local evaluation unaffected.

With posthog-dotnet (2026-08-05) and posthog-php (2026-08-05) now independently converging on
the same resilience behavior, this crosses the bar the prior change's follow-up task set for
adding a dedicated requirement.

`openspec/specs/local-feature-flag-evaluator/spec.md`'s existing "Error handling" section already
states the general principle ("Unsupported or inconclusive cases are surfaced as dedicated
'fall back to server' / 'inconclusive' signals rather than generic crashes") but does not name
*unrecognized operator strings* specifically, nor state the "only that flag, not the whole
project" scoping — leaving it untested and easy for a new SDK/operator combination to regress.

## What Changes

- **New requirement**: `Unrecognized property-filter operators degrade to inconclusive`,
  stating that an operator string the local evaluator does not recognize SHALL be treated as
  inconclusive for that flag only (deferring to remote evaluation for that flag), and SHALL NOT
  disable or fail local evaluation for other flags in the same evaluation pass.
- No changes to existing requirements or scenarios.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `local-feature-flag-evaluator`: gains one new requirement (`Unrecognized property-filter
  operators degrade to inconclusive`) with two scenarios. All existing requirements and
  scenarios are unchanged.

## Impact

- `openspec/specs/local-feature-flag-evaluator/spec.md` — source of truth, updated via this
  change's delta.
- Implementations: posthog-dotnet (PR #268, 2026-08-05) and posthog-php (PR #209, 2026-08-05)
  already conform. Other SDKs with local evaluation (posthog-js/node, posthog-python,
  posthog-ruby, posthog-go) were not confirmed either way in this pass — worth a follow-up audit
  (see `tasks.md` §4).
- **Low-confidence detail flagged for reviewer attention:** this proposal infers PHP's
  per-flag (not project-wide) scoping from the fact that `InconclusiveMatchException` is a
  known, caught-per-flag signal type elsewhere in the same evaluator (consistent with how a
  missing-property match is handled) — the source PR was not read line-by-line for the
  exception's catch site. Worth a reviewer double-check against the PHP diff directly.
