## Why

Six SDKs independently shipped the same local-evaluation feature within the same week, all
citing the same server-side change ([PostHog/posthog#72992](https://github.com/PostHog/posthog/pull/72992)):

- [posthog-js#4342](https://github.com/PostHog/posthog-js/pull/4342) — "support starts_with and
  ends_with in local evaluation" (`@posthog/core`, shared by posthog-node/posthog-js-lite)
- [posthog-python#820](https://github.com/PostHog/posthog-python/pull/820) — same feature
- [posthog-php#209](https://github.com/PostHog/posthog-php/pull/209) — same feature
- [posthog-ruby#229](https://github.com/PostHog/posthog-ruby/pull/229) — same feature
- [posthog-go#264](https://github.com/PostHog/posthog-go/pull/264) — same feature
- [posthog-dotnet#268](https://github.com/PostHog/posthog-dotnet/pull/268) — same feature, plus a
  resilience fix so an operator string the SDK doesn't recognize degrades to `Unknown`/inconclusive
  for that flag only, instead of throwing and disabling local evaluation for the whole project

Before this window, flags using the server's `starts_with` / `not_starts_with` / `ends_with` /
`not_ends_with` property-filter operators could not be evaluated locally in any of these SDKs —
every access fell back to remote evaluation. All six implementations converge on the same
semantics: stringify both sides, lowercase (ASCII case-folding), then compare with a
prefix/suffix check (and negate for the `not_*` variants) — mirroring the SDKs' existing
`icontains` handling.

`openspec/specs/local-feature-flag-evaluator/spec.md` describes property-filter matching only at
the behavioral level ("Match flag conditions locally. Evaluate property filters, rollout
percentages, multivariate overrides...") and never enumerates which operators a conformant local
evaluator must support — `icontains` isn't named either. This proposal adds the narrow, concrete
requirement needed to compare SDKs against a now-converged behavior, without attempting a
full enumeration of every existing operator (out of scope for this change).

## What Changes

- **New requirement**: `String prefix/suffix property filter operators`, describing
  `starts_with` / `not_starts_with` / `ends_with` / `not_ends_with` matching semantics
  (stringify, ASCII-lowercase, prefix/suffix compare, negate for `not_*`), with two scenarios
  (a matching case and a missing-property-value inconclusive case).
- No changes to existing requirements or scenarios.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `local-feature-flag-evaluator`: gains one new requirement (`String prefix/suffix property
  filter operators`) with two scenarios. All existing requirements and scenarios are unchanged.

## Impact

- `openspec/specs/local-feature-flag-evaluator/spec.md` — source of truth, updated via this
  change's delta.
- Implementations: posthog-js/posthog-node (via `@posthog/core`), posthog-python, posthog-php,
  posthog-ruby, posthog-go, and posthog-dotnet already conform as of the PRs listed above.
  posthog-android/posthog-ios/posthog-java/posthog-flutter were not checked in this pass for the
  same operator support — worth a follow-up audit (see `tasks.md` §4).
- No acceptance-harness changes in this proposal; the new scenarios are written for a future
  harness port.
- **Low-confidence detail flagged for reviewer attention:** posthog-dotnet's PR additionally
  changes how an *unrecognized* operator is handled (degrades that one flag to remote evaluation
  instead of throwing and disabling local evaluation project-wide). That resilience behavior is a
  plausible candidate for its own cross-SDK requirement, but only one SDK's change was confirmed
  to touch it in this pass — not included here to keep this change focused on the operator
  addition itself.
