## ADDED Requirements

### Requirement: Ingestion retry backoff is jittered

The SDK SHOULD apply random jitter to each ingestion retry wait, so that clients refused together do not return together. Without it, every client that failed during an outage retries on the same schedule and arrives at the endpoint as one burst each time it recovers.

Jitter SHALL scale the delay the SDK computed for that attempt rather than replace the schedule: the exponential or linear progression, the retry budget, and the backoff ceiling are unchanged, and a jittered wait SHALL NOT exceed the ceiling the SDK configured for its own backoff. The jittered wait SHALL stay within a bounded factor of the computed delay — the SDKs that implement this use a factor drawn uniformly from a window around 1, such as `[0.75, 1.25]` or `[0.5, 1.5]` — so spreading a fleet neither retries far earlier than the schedule intends nor leaves a recovered endpoint idle.

A `Retry-After` the endpoint sent SHALL remain a floor applied after jitter. Spreading a fleet SHALL NOT move a retry earlier than the endpoint asked for, and the floor itself stays clamped to the same ceiling, as the existing `Retry-After` handling requires.

Jitter is an availability measure, not a correctness one. An SDK whose platform offers no usable source of randomness, or whose randomness call fails, SHALL use the unjittered computed delay rather than skipping the wait.

#### Scenario: Retry waits vary around the computed delay
- **GIVEN** an SDK whose ingestion retry schedule computes a delay of 1000ms for the first retry
- **WHEN** many clients each take that first retry
- **THEN** their waits are not all 1000ms
- **AND** every wait stays within the SDK's bounded jitter factor of 1000ms

#### Scenario: A jittered wait never exceeds the backoff ceiling
- **GIVEN** an SDK whose backoff ceiling is 30 seconds
- **AND** the computed delay for this attempt has already reached the ceiling
- **WHEN** jitter is applied to that delay
- **THEN** the resulting wait is at most 30 seconds

#### Scenario: Retry-After stays a floor under a jittered wait
- **GIVEN** a retryable ingestion response carrying `Retry-After: 10` seconds
- **AND** the SDK's jittered delay for that attempt is 4 seconds
- **WHEN** the SDK schedules the retry
- **THEN** it waits at least 10 seconds
- **AND** the wait is still clamped to the SDK's backoff ceiling

#### Scenario: No randomness available falls back to the computed delay
- **GIVEN** an SDK whose source of randomness is unavailable or fails
- **WHEN** the SDK schedules a retry
- **THEN** it waits the unjittered computed delay
- **AND** it does not retry without waiting
