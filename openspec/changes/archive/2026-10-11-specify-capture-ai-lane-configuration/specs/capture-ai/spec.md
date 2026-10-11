## ADDED Requirements

### Requirement: AI lane configuration is scoped to the AI lane

Server SDKs that support AI capture SHALL expose the AI lane's compression mode,
queue capacity, and upload timeout as public options, defaulting to no
compression, 1000 events, and 30 seconds, and SHALL reject invalid values at
construction. Analytics configuration, including environment variables, SHALL
NOT change AI uploads, and the reverse. The per-event size cap MAY be exposed
and then only lowered; the batch-size target SHALL NOT be configurable.

#### Scenario: analytics compression does not reach the AI lane (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token" and gzip compression configured for analytics capture through the environment
- **AND** no AI lane compression is configured
- **WHEN** capture is called with distinct id "user-123" and event "button_clicked"
- **AND** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the request received on the analytics batch endpoint should be gzip encoded
- **AND** the request received on the AI batch endpoint should be uncompressed

#### Scenario: the per-event cap can be lowered but not raised (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK exposes a per-event size cap for the AI lane
- **WHEN** the SDK is initialized with a per-event cap below the SDK's default
- **AND** capture_ai is called with an event whose serialized size exceeds the configured cap but not the default
- **AND** the SDK is flushed
- **THEN** no event should reach the AI batch endpoint
- **WHEN** the SDK is initialized with a per-event cap above the SDK's default
- **THEN** the client construction should be rejected

#### Scenario: invalid AI lane configuration is rejected at construction (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **WHEN** the SDK is initialized with an AI lane queue capacity of zero
- **THEN** the client construction should be rejected
- **AND** no AI events should be enqueued
