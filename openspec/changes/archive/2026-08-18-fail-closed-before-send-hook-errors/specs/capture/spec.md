## MODIFIED Requirements

### Requirement: Canonical capture behavior

The SDK SHALL implement the canonical `capture` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client capture enriches an event with ambient context (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **AND** the current session id is "session-123"
- **AND** registered properties are:
  | property | value |
  | plan     | pro   |
- **WHEN** capture is called with event "Signed Up" and properties:
  | property | value |
  | source   | ad    |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event properties should include:
  | property    | value       |
  | source      | ad          |
  | plan        | pro         |
  | $session_id | session-123 |
- **AND** the enqueued event should include a timestamp and uuid

#### Scenario: Server capture requires an explicit distinct id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | source   | api   |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event properties should include:
  | property | value |
  | source   | api   |
  | $lib     | any   |
- **AND** the enqueued event should include an event uuid

#### Scenario: Capture honors opt-out state (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted out
- **WHEN** capture is called with event "Ignored Event"
- **THEN** no event should be enqueued
- **AND** no network request should be sent

#### Scenario: Capture can be modified or dropped by before-send (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send adds property "filtered" with value "yes"
- **WHEN** capture is called with event "Filtered Event"
- **THEN** one event named "Filtered Event" should be enqueued
- **AND** the enqueued event property "filtered" should equal "yes"
- **WHEN** before-send is changed to drop every event
- **AND** capture is called with event "Dropped Event"
- **THEN** no event named "Dropped Event" should be enqueued

#### Scenario: Capture drops an immediately delivered event when before-send throws (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** capture is configured for immediate delivery
- **AND** before-send throws an exception
- **WHEN** capture is called with event "Sensitive Event"
- **THEN** the capture call should not throw
- **AND** no event named "Sensitive Event" should be enqueued
- **AND** no network request should be sent
- **AND** the SDK should record a before-send warning
