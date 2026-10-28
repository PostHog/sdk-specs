## ADDED Requirements

### Requirement: Shutdown stops work when its timeout elapses

Where `shutdown` takes or defaults to a timeout, that timeout SHALL bound the whole teardown drain, not each delivery attempt within it. Once the budget is gone the SDK SHALL stop draining, SHALL NOT start another flush of the queue, and SHALL return. A bounded cleanup grace that a surface variant documents after the drain budget — Ruby's up to one second stopping workers and transports — MAY run before the call returns; it SHALL NOT deliver further queued events. The SDK SHOULD also check the remaining budget before each further delivery attempt within a flush — the next batch, a retry, or the next request of a size-split send — and stop rather than prepare a request it cannot complete. A stopped drain SHALL still return normally and SHALL be reported once, not once per abandoned request.

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
- **AND** the call should return without waiting for the held request
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

#### Scenario: A stopped drain keeps unsent events where the SDK persists its queue (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains more events than one ingestion request can carry
- **AND** the mock server will hold the next ingestion request past the shutdown timeout
- **WHEN** shutdown is called with a timeout of 100ms
- **THEN** events the drain did not send should remain in persistent storage where the SDK persists its queue
