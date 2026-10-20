## ADDED Requirements

### Requirement: Shutdown stops work when its timeout elapses

Where `shutdown` takes or defaults to a timeout, that timeout SHALL bound the whole teardown drain, not each delivery attempt within it. The SDK SHALL check the remaining budget before each further attempt — the next batch, a retry, or the next request of a size-split send — and once the budget is gone SHALL stop the drain rather than prepare a request it cannot complete. A stopped drain SHALL still return normally and SHALL be reported once, not once per abandoned request.

#### Scenario: Shutdown stops the drain once its timeout elapses (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains more events than one ingestion request can carry
- **AND** the mock server will hold the next ingestion request past the shutdown timeout
- **WHEN** shutdown is called with a timeout of 100ms
- **THEN** the call should not throw
- **AND** no further ingestion request should be sent after the timeout elapsed
- **AND** the SDK should record exactly one shutdown timeout diagnostic

#### Scenario: Shutdown within its timeout still drains every request (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will accept the next ingestion requests with status 200
- **AND** the event queue contains more events than one ingestion request can carry
- **WHEN** shutdown is called with a timeout of 30000ms
- **THEN** the mock server should receive every queued event
- **AND** the SDK should record no shutdown timeout diagnostic

#### Scenario: A stopped drain leaves no work reported as in flight (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains more events than one ingestion request can carry
- **AND** the mock server will hold the next ingestion request past the shutdown timeout
- **WHEN** shutdown is called with a timeout of 100ms
- **THEN** no events should be reported as still being sent
- **AND** events the drain did not send should remain in persistent storage where the SDK persists its queue
