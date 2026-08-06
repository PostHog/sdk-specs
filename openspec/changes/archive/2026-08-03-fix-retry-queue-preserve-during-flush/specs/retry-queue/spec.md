## MODIFIED Requirements

### Requirement: Canonical retry-queue behavior

The SDK SHALL implement the canonical `retry-queue` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Retry queue keeps events after transient failure
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will fail the next ingestion request with status 503
- **WHEN** capture is called with event "Retry Me"
- **AND** flush is called
- **THEN** the event named "Retry Me" should remain queued for retry

#### Scenario: Retry queue delivers events after a later success
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event named "Retry Me" is queued for retry
- **AND** the mock server will accept the next ingestion request with status 200
- **WHEN** retry queue processing runs
- **THEN** the mock server should receive event "Retry Me"
- **AND** the event named "Retry Me" should be removed from the retry queue

#### Scenario: Retry queue drops or bounds events when capacity is exceeded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and retry queue capacity is 2
- **WHEN** three events are added to the retry queue
- **THEN** the retry queue size should be 2
- **AND** the SDK should record a queue capacity warning

#### Scenario: Events captured while a full queue is flushing are preserved, not dropped
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and retry queue capacity is 3
- **AND** the mock server will delay the next ingestion request until released
- **WHEN** three events named "initial-1", "initial-2", and "initial-3" are added to the retry queue
- **AND** flush is called
- **AND** three replacement events named "replacement-1", "replacement-2", and "replacement-3" are added to the retry queue while the flush is in flight
- **AND** the delayed ingestion request is released and succeeds
- **THEN** the mock server should receive events "initial-1", "initial-2", and "initial-3" in the first batch
- **AND** the three replacement events should remain queued for delivery
- **AND** a subsequent flush should deliver the three replacement events
