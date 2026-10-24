## Why

The **Regular-expression criteria perform safe case-sensitive search** requirement only makes an
SDK defer when its own engine cannot handle a pattern: "Syntax unsupported by an SDK's regex
engine, or a regex execution failure, SHALL be inconclusive". It is silent about the larger
problem the SDKs just fixed — a pattern that compiles *and* executes locally, but whose result
disagrees with the flags service's Rust engine. Under the current wording a divergent definitive
boolean is compliant, and because it is definitive it also suppresses the remote fallback that
would have produced the right answer.

Seven SDKs converged on the same fix within two days, all referencing one agreed cross-SDK
approach ([posthog-js#5354](https://github.com/PostHog/posthog-js/pull/5354) and its
[cross-SDK discussion](https://github.com/PostHog/posthog-js/pull/5354#issuecomment-6321001477)):

| SDK | PR | Engine divergence it stopped guessing about |
|---|---|---|
| posthog-js (core/node/convex) | [#5354](https://github.com/PostHog/posthog-js/pull/5354) | `^\d+$` vs Arabic digits, `\p{L}` without Unicode mode, `\b`/`\B` vs the service's backtracking budget |
| posthog-python | [#1108](https://github.com/PostHog/posthog-python/pull/1108) | `^foo$` matching `"foo\n"`, `[a&&b]`, Unicode property escapes |
| posthog-go | [#387](https://github.com/PostHog/posthog-go/pull/387) | RE2 `^\d+$` vs `١`, lookarounds/backreferences that only the service compiles |
| posthog-android | [#876](https://github.com/PostHog/posthog-android/pull/876) | same classification for the server-side local evaluator |
| posthog-dotnet | [#351](https://github.com/PostHog/posthog-dotnet/pull/351) | same |
| posthog-php | [#277](https://github.com/PostHog/posthog-php/pull/277) | same |
| posthog-ruby | [#316](https://github.com/PostHog/posthog-ruby/pull/316) | same |

Two distinct rules come out of that work, and the spec states neither:

1. **A result-level anchor rule.** The service treats an unescaped `$` as end-of-input. Python's
   `re` matches it before a trailing line feed, so `^foo$` against `"foo\n"` locally returned the
   opposite of the service. posthog-python now makes end anchors strict.
2. **A deferral rule.** Where an engine's semantics cannot be made to agree — Unicode inputs under
   shorthand or property classes, word boundaries against the service's step budget,
   engine-specific syntax, catastrophic-backtracking shapes — the SDK now returns inconclusive and
   lets remote fallback answer, instead of returning its own definitive boolean.

## What Changes

- The requirement states that unescaped `^` and `$` anchor to the start and end of the whole
  input, with no trailing-line-feed exemption, and that an SDK whose engine differs SHALL
  translate the pattern or defer rather than return the divergent result.
- The requirement states that local regex matching is limited to a portable subset on which the
  SDK's engine agrees with the flags service, and that a pattern or input outside that subset is
  inconclusive **even when the local engine would return a definitive result**. Deferral keeps the
  existing guarantees: it MUST NOT become a match through `not_regex` or cohort negation, and
  local-only evaluation stays unresolved rather than guessing.
- The requirement allows an SDK to defer instead of returning the definitive no-match for an
  invalid pattern when its engine's notion of invalidity differs from the service's (posthog-go
  documents exactly this limitation for ambiguous brace forms such as `a{2 }`).
- The requirement notes that the subset is deliberately conservative: patterns that happen to
  agree may still defer, which increases remote flag requests and unresolved local-only results.
- New scenarios **Engine-divergent regex evaluation defers to the service** and **Portable ASCII
  regex criteria stay local**; the existing scenario outline gains strict end-anchor rows.
- The same scenarios are added to `acceptance/private/local-feature-flag-evaluator.feature`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `local-feature-flag-evaluator`: the **Regular-expression criteria perform safe case-sensitive
  search** requirement.

## Impact

Descriptive. Every SDK in the table above already behaves this way; SDKs that still return a
definitive local boolean for a divergent pattern now have a stated contract to converge on.

- **Remote traffic**: conservative deferral means more `/flags` requests and more unresolved
  local-only evaluations. That is the intended trade against a wrong flag value.
- **Acceptance adapters**: the new scenarios use steps for a divergence-class pattern/input pair
  and for asserting that no remote flag request was made, modelled on the existing
  `local evaluation should be inconclusive` step.
