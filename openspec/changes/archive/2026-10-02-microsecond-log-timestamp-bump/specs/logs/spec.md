## MODIFIED Requirements

### Requirement: Monotonic capture timestamps

The SDK SHALL generate `timeUnixNano` from the wall clock at millisecond precision or finer,
emitted as a string. An SDK whose platform clock is finer than a millisecond MAY keep that
precision instead of truncating to `current_unix_millis * 1_000_000`.

The SDK SHOULD keep timestamps strictly increasing across the records it captures, with each
record at least **1 µs** (1,000 ns) after the previous one: `max(clockNanos, previous + 1_000)`.
PostHog stores log timestamps with microsecond precision, so a smaller step is discarded on
ingestion and records captured in the same microsecond lose their order.

#### Scenario: two logs in the same millisecond
- **WHEN** two logs are captured within the same wall-clock millisecond
- **THEN** the second record's `timeUnixNano` is at least 1,000 greater than the first

#### Scenario: sub-millisecond clock
- **GIVEN** a platform clock with microsecond precision
- **WHEN** a log is captured at 1700000000000.123 ms
- **THEN** `timeUnixNano` MAY be `"1700000000000123000"` rather than `"1700000000000000000"`
