## Context

`Live span bounds` pairs a count bound (`maxLiveSpans`) with an age bound (`maxSpanAgeMs`). The
age bound was added only so a span leak cannot pin the count bound forever. The current text
applies it everywhere: any over-age live span is evicted at the next span start, end, or flush
tick. `posthog-node` implements that, sweeping on every `startSpan`. A review of the
`posthog-python` port (PostHog/posthog-python#953) showed the cost: a long span that its caller
does end is dropped, and its already-exported children are orphaned. The Python port changed to
sweep only at the count bound.

## Goals / Non-Goals

**Goals:**
- Keep leak recovery at the count bound exactly as strong as today.
- Stop dropping long spans that end normally below the bound.
- One rule both implementations follow, testable at the boundary.

**Non-Goals:**
- Changing `maxSpanAgeMs`'s name, type, or default.
- Adding a timer, or a per-span lifetime independent of the bound.
- Surfacing leaks below the bound some other way.

## Decisions

### Sweep only when `startSpan` finds the bound reached

**Decision.** At the bound, evict every live span whose age is at least `maxSpanAgeMs`, then
refuse with a no-op handle if, and only if, the bound is still reached. Never evict for age at
any other time.

**Alternatives considered.**
- *Keep eviction everywhere (current text).* Drops legitimate long work and orphans children,
  for no memory benefit: live bookkeeping is an id and a monotonic timestamp per span, already
  capped by the count bound.
- *Make eviction below the bound optional (`MAY`).* Leaves `posthog-node` compliant with no
  change, but lets two SDKs keep disagreeing about whether the same span is exported, which is
  how this divergence arose.
- *Evict at end or on the flush tick as well.* Same data loss as today, only later.

### Age boundary is inclusive

Both SDKs evict a span whose age equals `maxSpanAgeMs` (the sweep stops at the first entry
strictly newer than the cutoff). The text says "at least" so a conformance test at the exact
boundary matches the implementations.

## Risks / Trade-offs

- [A leak below the bound is no longer counted or warned about] → Its cost is bounded by
  `maxLiveSpans`; at the bound, the refusal and eviction both warn, as before.
- [A span that outlives `maxSpanAgeMs` in a process at the bound is still evicted] →
  Unchanged from today and documented, including the mobile-background case.

## Migration Plan

`posthog-python` already implements the new rule in its unmerged traces stack. `posthog-node`
moves the sweep behind the bound check in `@posthog/core`, shipped as a patch. No public API
changes. Rollback is restoring the unconditional sweep.

## Open Questions

None.
