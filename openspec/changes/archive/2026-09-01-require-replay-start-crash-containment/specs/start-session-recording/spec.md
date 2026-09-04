## ADDED Requirements

### Requirement: Replay start failures do not crash the host application

`start-session-recording` SHALL contain session replay setup and configuration failures. When the replay configuration is invalid, or the replay integration is unavailable or fails to initialize, the SDK SHALL no-op or log the failure and SHALL NOT throw into host application code. Session recording SHALL remain inactive after a contained setup failure. Promise-returning variants SHALL resolve rather than reject after a contained setup failure.

#### Scenario: Invalid replay configuration does not crash the caller
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured with an invalid replay configuration
- **AND** session recording is inactive
- **WHEN** start session recording is called
- **THEN** the call should not throw
- **AND** session recording should remain inactive

#### Scenario: Unavailable replay integration does not crash the caller
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the session replay integration is unavailable
- **AND** session recording is inactive
- **WHEN** start session recording is called
- **THEN** the call should not throw
- **AND** session recording should remain inactive

#### Scenario: Replay integration initialization failure does not crash the caller
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** the session replay integration fails to initialize
- **AND** session recording is inactive
- **WHEN** start session recording is called
- **THEN** the call should not throw
- **AND** promise-returning start variants should resolve rather than reject
- **AND** session recording should remain inactive
