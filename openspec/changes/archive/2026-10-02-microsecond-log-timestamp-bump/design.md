## Overview

This change does not add a capability. It fixes the **Monotonic capture timestamps** requirement
so that the ordering it asks for survives ingestion, which stores log timestamps at microsecond
precision.

## Key Decisions

- Bump by 1 µs, not 1 ns. 1 µs is the smallest step `DateTime64(6)` keeps, so it is the smallest
  bump that preserves order once stored.
- Express the bump as `max(clockNanos, previous + 1_000)` rather than "+1 µs when the clock hasn't
  advanced". The two are the same on a millisecond clock. On a finer clock, a value that advanced by
  less than 1 µs would still tie once stored, and the `max` form covers it.
- Allow a finer clock rather than require one. A finer clock is what kept posthog-ios ordered on
  device, but not every runtime exposes one (`Date.now()` in JavaScript is milliseconds), and the
  bump alone is enough to keep order.
- Keep the bump a SHOULD, as before. A counter that runs ahead of the wall clock during a burst
  (more than 1,000 records in a millisecond) is the accepted cost. It returns to the wall clock as
  soon as the clock passes it.

## Alternatives Considered

- **Keep +1 ns.** Rejected. It preserves order on the wire only, and measured collisions once
  stored were 463–480 of 500 on posthog-android.
- **Require `current_unix_millis * 1_000_000` everywhere and accept the ties.** Rejected. It would
  make posthog-ios coarser and lose the ordering it has today.
- **Store nanoseconds server-side.** Out of scope for an SDK contract, and the bump makes it
  unnecessary for ordering.

## Open Questions

None.
