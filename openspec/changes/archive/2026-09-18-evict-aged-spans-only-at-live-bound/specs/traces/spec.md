## MODIFIED Requirements

### Requirement: Live span bounds

The SDK SHALL bound live spans: at most `maxLiveSpans` concurrently. `maxSpanAgeMs` is the
leak-recovery threshold for that bound. Its default SHALL comfortably exceed the platform's
realistic worst-case trace duration — on the order of an hour, not minutes (production PostHog
traces routinely exceed 10 minutes); mobile ports MAY choose a larger default since backgrounded
time counts. Age SHALL be the monotonic elapsed time since handle creation, independent of any
caller-supplied `startTime` — a backdated span is not instantly evicted, a future-dated
leaked span cannot evade the bound, and wall-clock jumps do not affect it.

At the count bound, `startSpan` SHALL first evict from live accounting every live span whose
age is at least `maxSpanAgeMs` — an evicted handle becomes a no-op (never exported) — and SHALL
return a no-op handle if, and only if, the bound is still reached. Eviction prevents a span leak
from permanently disabling tracing for the rest of the process. The SDK SHALL NOT evict a span
for age at any other time: a live span past `maxSpanAgeMs` that has not been evicted at the
bound SHALL, when it ends, go through the same end-time gates and export path as any other
span. Evicting it would drop legitimate long work (a batch job, a migration) and leave its
already-exported children pointing at a `parentSpanId` that never lands. No dedicated timer is required. A span spanning a long mobile background interval can
still be evicted if the process reaches the count bound meanwhile; that is expected behavior,
not a defect. All span drops — live-bound refusals, age evictions, queue overflow, and
end-time gate drops — SHALL increment a single per-instance dropped-spans counter, with a
warning at most once per flush interval naming the count and reason mix.

#### Scenario: leaked spans are bounded
- **GIVEN** the live-span bound is reached because spans are started but never ended
- **WHEN** the app calls `startSpan` again
- **THEN** it receives a no-op handle, the dropped count increments, and SDK memory does not
  grow further

#### Scenario: age eviction re-enables tracing
- **GIVEN** `maxLiveSpans` handles leaked (started, never ended) longer than `maxSpanAgeMs`
  ago
- **WHEN** the age bound passes and the app calls `startSpan`
- **THEN** the leaked spans are evicted (never exported) and the new span is a real span

#### Scenario: a long span below the bound is exported
- **GIVEN** fewer than `maxLiveSpans` live spans, one of them started longer than
  `maxSpanAgeMs` ago
- **WHEN** the app starts another span, then ends the old one
- **THEN** the old span is not evicted, and it passes the end-time gates and is exported with
  its full duration like any other span
