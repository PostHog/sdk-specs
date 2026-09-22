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

#### Scenario: Server identify delivers a profile update for explicit distinct id (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with distinct id "user-123" and properties `{ "email": "user@test.test", "active": false, "score": 0, "note": null }`
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` equals `user-123`
- **AND** its `$set` equals the supplied JSON object, preserving boolean, numeric and null values

#### Scenario: Server identify delivers nested user properties (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with distinct id "user-456" and properties `{ "preferences": { "theme": "dark" }, "tags": ["beta", "team"] }`
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` equals `user-456`
- **AND** its `$set` equals the supplied nested JSON object

#### Scenario: Identify validates distinct id (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called without a distinct id
- **THEN** identity state should not change
- **AND** no identity event should be enqueued
