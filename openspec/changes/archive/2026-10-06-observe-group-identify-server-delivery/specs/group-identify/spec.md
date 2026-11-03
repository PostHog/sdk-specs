## MODIFIED Requirements

### Requirement: Canonical group-identify behavior

The SDK SHALL implement the canonical `group-identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below. Supplied group profile properties SHALL be nested under `properties.$group_set` on the `$groupidentify` event.

#### Scenario: Server group identify delivers scalar group properties for an explicit distinct id (@server)

- **GIVEN** a fresh isolated SDK instance and mock receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** group identify is called with JSON arguments:
  ```json
  {"group_type":"company","group_key":"company-123","distinct_id":"user-123","properties":{"plan":"pro","active":false,"score":0,"note":null}}
  ```
- **AND** pending captures are flushed
- **THEN** exactly one capture request SHALL have been received containing exactly one parsed event
- **AND** the received event SHALL have `event` equal to `$groupidentify` and `distinct_id` equal to `user-123`
- **AND** the received event properties SHALL have `$group_type` equal to `company` and `$group_key` equal to `company-123`
- **AND** the received event property `$group_set` SHALL equal JSON `{"plan":"pro","active":false,"score":0,"note":null}`

#### Scenario: Server group identify preserves nested and literal group properties (@server)

- **GIVEN** a fresh isolated SDK instance and mock receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** group identify is called with JSON arguments:
  ```json
  {"group_type":"company","group_key":"company-456","distinct_id":"user-456","properties":{"preferences":{"theme":"dark"},"tags":["beta","team"],"$group_type":"literal-type","$group_key":"literal-key"}}
  ```
- **AND** pending captures are flushed
- **THEN** exactly one capture request SHALL have been received containing exactly one parsed event
- **AND** the received event SHALL have `event` equal to `$groupidentify` and `distinct_id` equal to `user-456`
- **AND** the received event properties SHALL have `$group_type` equal to `company` and `$group_key` equal to `company-456`
- **AND** the received event property `$group_set` SHALL equal JSON `{"preferences":{"theme":"dark"},"tags":["beta","team"],"$group_type":"literal-type","$group_key":"literal-key"}`

#### Scenario: Server group identify delivers a group identity without properties (@server)

- **GIVEN** a fresh isolated SDK instance and mock receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** group identify is called with JSON arguments:
  ```json
  {"group_type":"company","group_key":"company-123","distinct_id":"user-123"}
  ```
- **AND** pending captures are flushed
- **THEN** exactly one capture request SHALL have been received containing exactly one parsed event
- **AND** the received event SHALL have `event` equal to `$groupidentify` and `distinct_id` equal to `user-123`
- **AND** the received event properties SHALL have `$group_type` equal to `company` and `$group_key` equal to `company-123`

#### Scenario: Group identify emits a group profile update event (@client)

- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called with type "company", key "company-123", and properties:
  | property | value |
  | plan     | pro   |
- **THEN** one event named "$groupidentify" should be enqueued
- **AND** the enqueued event properties should include:
  | property        | value       |
  | $group_type     | company     |
  | $group_key      | company-123 |
  | $group_set.plan | pro         |

#### Scenario: Group identify requires type and key (@both)

- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called without a group key
- **THEN** no event named "$groupidentify" should be enqueued
- **AND** the SDK should record a validation warning

#### Scenario: Group identify does not replace registered group context (@client)

- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called with type "company", key "company-123", and no properties
- **THEN** registered groups should not change
