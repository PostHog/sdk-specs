## Why

`Live span bounds` requires that no live span outlive `maxSpanAgeMs`: an over-age span is evicted
and never exported, checked lazily at the next span start, span end, or flush tick. The rule exists
for one reason, which the requirement states: eviction "prevents a span leak from permanently
disabling tracing for the rest of the process".

Evicting below the count bound does nothing for that goal, and it drops real data. A review of the
`posthog-python` traces pipeline (PostHog/posthog-python#953) reproduced the failure: a root span
older than `maxSpanAgeMs` that its caller does end is never exported, and its children, already
exported, arrive as orphans whose `parentSpanId` never lands. The default is one hour, and a
batch-job or migration wrapper span longer than that is realistic. The reviewer's observation was
that "the leak-recovery goal is served equally well by sweeping only when
`len(_live_spans) >= max_live_spans`".

Below the bound, an old live span costs nothing: every implementation tracks only an id and a
monotonic timestamp per live span, never the span itself, so a leaked handle stays collectable.
The count bound already caps that bookkeeping.

The two SDKs that implement traces currently disagree:

| SDK | When over-age spans are evicted |
| --- | --- |
| `posthog-node` (shared core, `_evictAgedSpans()` in `packages/core/src/traces/index.ts`) | on every `startSpan` — matches the current text |
| `posthog-python` (unmerged traces stack ending at PostHog/posthog-python#957) | only when `startSpan` finds the count bound reached — adopted from the #953 review |

Node's behavior is also nondeterministic in the case it should settle: whether an over-age span
survives depends on whether any other span happened to start before it ended.

## What Changes

- Evict over-age spans only when `startSpan` finds the live-span count at `maxLiveSpans`, and
  return a no-op handle if, and only if, the bound is still reached after that sweep.
- Forbid age eviction below the bound, so a long span that ends is exported with its full
  duration.
- Recast `maxSpanAgeMs` as the leak-recovery threshold for the count bound, not a standalone
  per-span lifetime.
- Narrow the mobile-background note: such a span is evicted only if the process reaches the bound
  meanwhile.
- Add a scenario for a long span below the bound. The two existing scenarios still hold as
  written.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `traces`: `Live span bounds` evicts over-age spans only at the count bound.

## Impact

- `posthog-python`: the unmerged traces stack already implements this.
- `posthog-node`: the sweep moves behind the bound check in `@posthog/core`, shipped
  as a patch (PostHog/posthog-js, branch `fix/traces-age-sweep-at-bound`). No API change:
  `maxSpanAgeMs` keeps its name, type, and default.
- Users lose no spans they get today. Spans that ran past `maxSpanAgeMs` and ended, previously
  dropped with their children orphaned, are now exported.
- Leak recovery is unchanged: once leaks fill the bound, the next `startSpan` after they age out
  evicts them and records a real span, as before.
- Leaks below the bound are no longer evicted, so they are no longer counted as drops or warned
  about until the bound is reached. Their cost is an id and a timestamp each, capped by the bound.
- No other SDK implements traces yet, so no further ports are affected.
