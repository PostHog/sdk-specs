## ADDED Requirements

### Requirement: Client-side capture rate limiting never loses tokens to a clock change

A client SDK that drops captures on a client-side rate limit (today posthog-js, as listed under "Drop silently") SHALL meter that limit with a token bucket persisted alongside the rest of its state. The bucket holds a token balance and the clock instant the balance was last computed at. Its size and refill rate are configurable per platform convention (posthog-js: `rate_limiting.events_per_second`, default 10, and `rate_limiting.events_burst_limit`, default ten times the per-second rate and never below it); a bucket with no persisted state starts full at the burst limit.

The bucket is refilled from the device's wall clock, which can move backward — a manual change, an NTP correction, a timezone daemon. The refill SHALL therefore be monotonic:

- The SDK SHALL refill the balance by the elapsed time since the stored instant, counting elapsed time as zero when the clock is behind that instant, multiplied by the per-second rate, and SHALL cap the balance at the burst limit. A backward clock change refills nothing and SHALL NOT remove tokens from the bucket.
- The SDK SHALL store the later of the stored instant and the current instant, so the bucket does not refill again until the clock passes the latest instant it has seen. A rollback followed by the clock catching up SHALL NOT refill the bucket twice for the same stretch of real time.
- An admitted capture SHALL consume one token and the balance SHALL NOT go below zero. A capture is rate limited when fewer than one token is available.

A backward clock change SHALL only pause refill until the clock catches up. It SHALL NOT take away tokens the bucket already held, so a capture that had a token available before the change is still admitted after it.

#### Scenario: A backward clock change does not drop the next capture (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and client rate limiting of 1 capture per second with a burst limit of 100
- **WHEN** capture is called with event "Before Rollback"
- **AND** the SDK clock moves backward by "143 seconds"
- **AND** capture is called with event "After Rollback"
- **THEN** one event named "Before Rollback" should be enqueued
- **AND** one event named "After Rollback" should be enqueued

#### Scenario: The bucket does not refill until the clock passes the latest instant it has seen (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and client rate limiting of 1 capture per second with a burst limit of 2
- **WHEN** capture is called with event "One"
- **AND** capture is called with event "Two"
- **AND** the SDK clock moves backward by "10 seconds"
- **AND** capture is called with event "Three"
- **AND** the SDK clock advances by "10 seconds"
- **AND** capture is called with event "Four"
- **AND** the SDK clock advances by "1 second"
- **AND** capture is called with event "Five"
- **THEN** one event named "One" should be enqueued
- **AND** one event named "Two" should be enqueued
- **AND** no event named "Three" should be enqueued
- **AND** no event named "Four" should be enqueued
- **AND** one event named "Five" should be enqueued
