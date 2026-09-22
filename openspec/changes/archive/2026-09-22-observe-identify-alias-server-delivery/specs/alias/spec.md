## MODIFIED Requirements

### Requirement: Canonical alias behavior

The SDK SHALL implement the canonical `alias` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client alias links the current anonymous identity to a known identity (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **WHEN** alias is called with alias "user-123"
- **THEN** one event named "$create_alias" should be enqueued
- **AND** the enqueued event distinct id should be "anon-123"
- **AND** the enqueued event properties should include:
  | property    | value    |
  | alias       | user-123 |
  | distinct_id | anon-123 |

#### Scenario: Server alias delivers the explicit previous and new identities (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** alias is called with previous distinct id "anon-123" and alias "user-123"
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$create_alias` event
- **AND** the received event's root `distinct_id` equals `anon-123`
- **AND** the received event property `alias` equals `user-123`

#### Scenario: Server alias links a second pair of explicit identities (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** alias is called with previous distinct id "temporary-7" and alias "customer-42"
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$create_alias` event
- **AND** the received event's root `distinct_id` equals `temporary-7`
- **AND** the received event property `alias` equals `customer-42`

#### Scenario: Alias is dropped when required identities are missing (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** alias is called without a previous distinct id
- **THEN** no event should be enqueued
- **AND** the SDK should record a validation warning
