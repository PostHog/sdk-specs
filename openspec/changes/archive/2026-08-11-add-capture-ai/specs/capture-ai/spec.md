## ADDED Requirements

### Requirement: Canonical capture_ai behavior

Server SDKs that support AI capture SHALL implement `capture_ai` as described
by this spec. Implementations MAY adapt method names, parameter casing, and
option naming to platform idioms, but MUST preserve the observable outcomes in
the scenarios below.

#### Scenario: capture_ai mirrors capture's parameters and returns the event UUID (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and properties:
  | property  | value |
  | $ai_model | gpt   |
- **THEN** one event named "$ai_generation" should be enqueued on the AI route
- **AND** the call should return the enqueued event's uuid
- **AND** the enqueued event should include a timestamp and uuid

#### Scenario: capture_ai rides an isolated route to the AI endpoint (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123" and event "button_clicked"
- **AND** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the analytics batch endpoint should receive only "button_clicked"
- **AND** the AI batch endpoint should receive only "$ai_generation"

#### Scenario: capture never reroutes AI-named events (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the analytics batch endpoint should receive "$ai_generation"
- **AND** the AI batch endpoint should receive no events

#### Scenario: the SDK generates a UUID when the caller supplies none (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation" and no uuid
- **AND** the SDK is flushed
- **THEN** the event received on the AI batch endpoint should carry a client-generated uuid
- **WHEN** capture_ai is called with an explicit valid uuid
- **THEN** the event received on the AI batch endpoint should carry exactly that uuid
- **AND** handling of an invalid supplied uuid is platform-idiomatic (replace or reject)

#### Scenario: oversized events are dropped logging name and size only (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with an event whose serialized size exceeds the per-event cap
- **AND** the SDK is flushed
- **THEN** no event should reach the AI batch endpoint
- **AND** the SDK should log the event name and byte size
- **AND** the log output should not contain the event's property values

#### Scenario: capture_ai never throws (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** the AI batch endpoint is unreachable
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the caller should observe no exception

### Requirement: Full AI capture flag

The SDK SHALL expose a single boolean option (default false), named
`enable_full_ai_capture` adapted to platform convention, that governs what the
SDK's AI wrapper libraries capture. It SHALL NOT alter payloads passed to
`capture_ai` directly.

#### Scenario: wrapper media is redacted by default and passed through when enabled (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **WHEN** the client has the flag unset
- **THEN** the captured content should replace the media with a type-aware placeholder
- **WHEN** the client has the flag set to true
- **THEN** the captured content should contain the media unmodified
- **AND** no string truncation should be applied to the captured content

#### Scenario: privacy mode wins over the flag (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **AND** the client has privacy mode enabled and the flag set to true
- **THEN** the captured event should carry no input or output content
