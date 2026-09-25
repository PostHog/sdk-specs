## MODIFIED Requirements

### Requirement: Canonical identify behavior

The SDK SHALL implement the canonical `identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below. Server SDKs MUST resolve an omitted per-call distinct id from request-scoped analytics context when available, otherwise generate a fresh UUID for the event and set `$process_person_profile` to `false` unless the caller explicitly supplied that property. An explicit per-call distinct id MUST take precedence over context. Server `identify` MUST NOT throw or reject to the application when the distinct id is omitted. Generated ids MUST NOT be used for feature-flag evaluation or persisted as ambient user identity.

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

#### Scenario: Server identify without explicit or contextual identity generates a personless UUID (@server)
- **GIVEN** an isolated server SDK instance with no request-scoped identity and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with person properties and no explicit distinct id
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` is a generated UUID
- **AND** its `$set` equals the supplied person properties
- **AND** its `$process_person_profile` is `false`
- **AND** the SDK call does not throw or reject

#### Scenario: Server identify uses request-scoped analytics identity before generating one (@server)
- **GIVEN** an isolated server SDK instance with request-scoped analytics distinct id "context-user"
- **WHEN** identify is called without an explicit distinct id
- **AND** pending captures are flushed
- **THEN** the received `$identify` event's root `distinct_id` is "context-user"
- **AND** the SDK call does not throw or reject

#### Scenario: Server identify uses the explicit id before request-scoped analytics identity (@server)
- **GIVEN** an isolated server SDK instance with request-scoped analytics distinct id "context-user"
- **WHEN** identify is called with explicit distinct id "explicit-user"
- **AND** pending captures are flushed
- **THEN** the received `$identify` event's root `distinct_id` is "explicit-user"

#### Scenario: Client identify validates missing distinct id (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called without a distinct id
- **THEN** identity state should not change
- **AND** no identity event should be enqueued
