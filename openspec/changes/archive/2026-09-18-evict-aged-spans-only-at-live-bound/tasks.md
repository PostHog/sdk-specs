## 1. Establish the Contract

- [x] 1.1 Read when each traces implementation evicts over-age spans: `posthog-node` on every `startSpan`, `posthog-python` only at the count bound.
- [x] 1.2 Confirm the requirement's stated purpose for age eviction is leak recovery at the count bound.
- [x] 1.3 Confirm live-span bookkeeping holds only ids and timestamps in both SDKs, so an old live span below the bound costs nothing.
- [x] 1.4 Reproduce the loss: a span older than `maxSpanAgeMs` that ends is dropped under the current text, and its exported children are orphaned (PostHog/posthog-python#953 review).
- [x] 1.5 Confirm both SDKs evict a span whose age equals `maxSpanAgeMs`, and word the boundary to match.

## 2. Write the Delta

- [x] 2.1 Rewrite `Live span bounds` to evict over-age spans only when `startSpan` finds the bound reached, return a no-op handle if, and only if, the bound is still reached, and forbid age eviction at any other time.
- [x] 2.2 Narrow the mobile-background note to the at-bound case.
- [x] 2.3 Add the `a long span below the bound is exported` scenario.

## 3. Validate and Review

- [x] 3.1 Run `openspec validate --specs --strict --no-interactive` and `openspec validate evict-aged-spans-only-at-live-bound --strict`.
- [x] 3.2 Run `git diff --check`.
- [x] 3.3 Prepare the matching `posthog-node` change in PostHog/posthog-js (`fix/traces-age-sweep-at-bound`), with a test that fails on the current sweep.
- [x] 3.4 Decide whether acceptance scenarios belong in `acceptance/`. Spec scenarios suffice: `acceptance/` carries no traces feature file yet.
- [x] 3.5 Archive into the canonical `traces` spec.
