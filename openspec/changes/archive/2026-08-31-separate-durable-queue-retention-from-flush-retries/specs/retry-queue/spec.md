## ADDED Requirements

### Requirement: Durable queue retention is independent from flush retry scheduling

When an SDK owns a bounded durable queue, it MUST retain the affected queue entries after a retryable delivery failure, including when the failure-driven flush sequence exhausts its retry-count budget. Exhausting that budget MAY end the active sequence, but MUST NOT delete or clear queued entries.

A durable queue entry MAY be removed only when its exact entry is acknowledged successfully, it receives a terminal non-retryable disposition, capacity eviction selects it, or an explicit documented lifecycle operation clears it. Retry attempts MUST use bounded backoff, and later independent flush triggers MUST be able to retry retained entries subject to the current cooldown.

#### Scenario: Pre-response transport failures exceed the retry budget
- **GIVEN** a bounded durable queue containing event "Keep Me"
- **AND** the normal retry-count budget permits 2 retries after the initial ingestion attempt
- **WHEN** 3 attempts fail with a recognized transient transport error before any HTTP response
- **THEN** event "Keep Me" remains durably queued
- **AND** ending the active retry sequence does not clear any queued entry

#### Scenario: Retryable HTTP failures exceed the retry budget
- **GIVEN** a bounded durable queue containing event "Retry Later"
- **AND** the normal retry-count budget permits 2 retries after the initial ingestion attempt
- **WHEN** 3 attempts receive HTTP 503
- **THEN** event "Retry Later" remains durably queued
- **WHEN** a later independent flush receives HTTP 200
- **THEN** event "Retry Later" is delivered and removed

### Requirement: Known-offline queues pause delivery attempts

When the SDK can positively determine that the network is unavailable, it MUST pause queue transport attempts without consuming the flush retry budget. It MUST continue to accept records subject to the existing capacity policy. When connectivity returns, queued work MUST become eligible for normal flush processing again. Unknown or unavailable connectivity state MAY fall back to an attempted request and normal transport-error handling.

#### Scenario: Offline queue resumes after connectivity returns
- **GIVEN** the SDK reports that the network is unavailable
- **WHEN** event "Captured Offline" is added and queue timers run
- **THEN** no ingestion request is attempted
- **AND** no flush retry attempt is consumed
- **AND** event "Captured Offline" remains queued
- **WHEN** the network becomes available and queue processing runs
- **THEN** event "Captured Offline" is delivered

### Requirement: Successful flushes acknowledge queue entries by identity

A flush MUST snapshot stable identities for the queue entries included in its request. After success, it MUST remove only matching entries that are still present in the live queue. It MUST NOT acknowledge a batch by deleting the current first N queue positions when those positions may have changed during transport.

#### Scenario: Full queue is replaced with identical payloads during an in-flight flush
- **GIVEN** a durable queue with capacity 3 whose entries have queue identities "initial-1", "initial-2", and "initial-3"
- **AND** all three entries contain the same serialized event payload
- **AND** a flush snapshots those three queue identities
- **WHEN** entries with queue identities "replacement-1", "replacement-2", and "replacement-3" and the same serialized payload are accepted
- **AND** capacity eviction replaces the three initial entries
- **AND** the in-flight flush succeeds
- **THEN** queue identities "replacement-1", "replacement-2", and "replacement-3" remain queued
- **AND** a later flush delivers the three replacement entries
