## ADDED Requirements

### Requirement: AI capture drops null-valued object properties

`capture_ai` and its immediate/awaitable variants SHALL follow capture's "Capture drops null-valued object properties" requirement for caller-supplied custom properties, including nested objects and objects inside arrays. Null array elements SHALL retain their positions. This is a specific normalization exception to manual AI capture's payload pass-through promise, not permission to add redaction, truncation, or media processing.

#### Scenario: AI capture drops null-valued properties on its delivery route (@server)
- **GIVEN** an initialized SDK supporting AI capture with no property-changing hooks or filters
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2]}`
- **AND** the SDK is flushed
- **THEN** one event named "$ai_generation" should be received on the AI batch endpoint
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2]}`
- **AND** the analytics batch endpoint should receive no events
