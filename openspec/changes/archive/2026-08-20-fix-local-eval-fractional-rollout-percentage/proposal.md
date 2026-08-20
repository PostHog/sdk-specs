## Why

Two independently-maintained SDKs fixed the same local-evaluation bug this week:
`rollout_percentage` was deserialized/typed as an integer, silently truncating fractional
rollouts (e.g. a flags-service rollout of `0.1%`) and producing wrong bucketing decisions.

- [posthog-android#699](https://github.com/PostHog/posthog-android/pull/699) — the shared
  `posthog` core module (used by both the client SDK and the `posthog-server` Java/Kotlin SDK)
  widened `FlagConditionGroup.rolloutPercentage` from `Int?` to `Double?`. The PR's own test
  comment: "A fractional rollout such as 0.1% has to survive deserialization and bucketing ...
  Truncating the percentage to an integer would put both users outside the bucket."
- [posthog-dotnet#292](https://github.com/PostHog/posthog-dotnet/pull/292) — the same change,
  `LocalEvaluationApiResult.FeatureFlagGroup.RolloutPercentage` widened from `int?` to `double?`,
  with the same fractional-bucketing test rationale.

`openspec/specs/local-feature-flag-evaluator/spec.md` never states the numeric type of
`rollout_percentage` at all — step 6 of "Behavior" just says the evaluator matches "rollout
percentages" without saying whether fractional values must be preserved. That's exactly the gap
that let two SDKs ship the same truncation bug independently. This mirrors the precedent set by
the existing "String prefix/suffix property filter operators" and "Unrecognized property-filter
operators degrade to inconclusive" requirements in this same spec file, both added after
real cross-SDK gaps were found.

## What Changes

Add a new requirement to `local-feature-flag-evaluator/spec.md`: the evaluator SHALL treat
`rollout_percentage` as a floating-point number and MUST NOT truncate or round it before
comparing it against the bucketing hash. Two scenarios illustrate a fractional rollout matching
correctly and a boundary case (100.0 / 0.0) continuing to work after widening the type.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `local-feature-flag-evaluator`: new "Fractional rollout percentages" requirement with two
  scenarios. No changes to existing requirements or scenarios.

## Impact

- `openspec/specs/local-feature-flag-evaluator/spec.md` — source of truth, requirement added
  directly (small, self-contained addition; archived immediately per this repo's convention for
  focused fixes, matching the sibling `2026-08-07-add-local-eval-string-operators` and
  `2026-08-12-add-local-eval-unknown-operator-inconclusive` changes already in this history).
- Not investigated: whether other SDKs with a local evaluator (posthog-python, posthog-node,
  posthog-php, posthog-ruby, posthog-go) already handle `rollout_percentage` as a float or share
  this same bug — only posthog-android and posthog-dotnet had a confirmed, merged fix in this
  run's lookback window. Worth a follow-up compliance pass across the remaining local evaluators.
