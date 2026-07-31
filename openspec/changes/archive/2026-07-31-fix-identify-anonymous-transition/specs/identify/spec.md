## MODIFIED Requirements

### Requirement: Canonical identify behavior

The SDK SHALL implement the canonical `identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client identify changes the current distinct id and sends identity properties (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **WHEN** identify is called with distinct id "user-123" and properties:
  | property | value          |
  | email    | user@test.test |
- **THEN** get distinct id should return "user-123"
- **AND** one event named "$identify" should be enqueued
- **AND** the enqueued event properties should include:
  | property             | value          |
  | distinct_id          | user-123       |
  | $anon_distinct_id    | anon-123       |
  | $set.email           | user@test.test |

#### Scenario: Identify with a distinct id already matching the anonymous id transitions to identified (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **AND** the SDK has not yet identified a user
- **WHEN** identify is called with distinct id "anon-123"
- **THEN** get distinct id should return "anon-123"
- **AND** one event named "$set" should be enqueued
- **AND** no event named "$identify" should be enqueued

#### Scenario: Server identify sends a profile update for explicit distinct id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called with distinct id "user-123" and properties:
  | property | value          |
  | email    | user@test.test |
- **THEN** one event named "$identify" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event property "$set.email" should equal "user@test.test"

#### Scenario: Identify validates distinct id (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called without a distinct id
- **THEN** identity state should not change
- **AND** no identity event should be enqueued
