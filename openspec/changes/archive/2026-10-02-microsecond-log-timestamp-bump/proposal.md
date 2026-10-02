## Why

The **Monotonic capture timestamps** requirement asks for `current_unix_millis * 1_000_000` plus a
+1ns bump, so that logs captured in the same millisecond keep their order. That order does not
survive ingestion:

- `capture-logs` converts `timeUnixNano` with `DateTime::from_timestamp_nanos`
  (`rust/capture-logs/src/log_record.rs`), and
- the `logs` table stores `timestamp DateTime64(6)` (`posthog/clickhouse/logs/logs34.py`), which is
  microseconds.

The +1ns steps are dropped, so every log in a millisecond lands on the same stored timestamp.

Measured with 500 logs in a tight loop and 500 from a thread pool, counting records whose stored
(microsecond) timestamp collides with another's:

| SDK | Clock | Bump | Collisions once stored (of 500) | Smallest gap between logs |
|---|---|---|---|---|
| posthog-android `main` (Pixel 9 emulator, Android 17) | ms | +1ns | 463–480 | 1 ns |
| posthog-ios `main` (iPhone 14 Pro Max, iOS 26) | ~0.24 µs (`Date`) | none | 0 | 20 µs |

Android follows the spec exactly and loses ordering for nearly every burst. iOS breaks the SHALL,
because it doesn't truncate to milliseconds, and it keeps the order. Bringing iOS into line with the
spec as written would make it lose ordering too.

## What Changes

- **Finer clocks are allowed.** `timeUnixNano` SHALL be at millisecond precision or finer. An SDK
  whose platform clock is finer MAY keep that precision rather than truncating.
- **The bump is 1 µs, not 1 ns.** Each record SHOULD be at least 1,000 ns after the previous one,
  `max(clockNanos, previous + 1_000)`, the smallest step that survives microsecond storage. Up to
  1,000 records per millisecond keep their order before the counter runs ahead of the wall clock,
  and it falls back in line as soon as the clock passes it.
- The same-millisecond scenario now asserts a step of at least 1,000. A new scenario covers the
  sub-millisecond clock.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `logs`: the **Monotonic capture timestamps** requirement.

## Impact

Not a breaking change. `timeUnixNano` keeps its type and meaning; only the step between
same-instant records and the permitted precision change. No service change is needed.

- **posthog-android** uses `currentTimeMillis()` with a +1ns bump. Changing the step to +1,000 ns
  conforms.
- **posthog-js** (web, React Native) builds `String(Date.now()) + '000000'` with no bump at all
  (`packages/core/src/logs/logs-utils.ts`), so same-millisecond logs already tie on the wire. It
  needs the bump.
- **posthog-ios** keeps a sub-millisecond clock, which is now allowed. It has no bump, which leaves
  it short of the SHOULD, though no collision was observed on device. Adding
  `max(clockNanos, previous + 1_000)` at microsecond resolution conforms.
