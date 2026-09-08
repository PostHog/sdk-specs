## ADDED Requirements

### Requirement: AI capture preserves explicit null properties

`capture_ai` and its immediate/awaitable variants SHALL follow capture's "Explicit null capture properties are valid JSON data" requirement for caller-supplied custom properties, including nested object values and array elements. Using the AI route MUST NOT introduce null stripping.

#### Scenario: AI capture preserves null properties on its delivery route (@server)
- **GIVEN** an initialized SDK supporting AI capture with no property-changing hooks or filters
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and custom properties represented by JSON `{"optional":null,"nested":{"value":null},"items":["first",null,"last"]}`
- **AND** the SDK is flushed
- **THEN** the event received on the AI endpoint should contain every supplied custom property with the same JSON value
- **AND** "items" should contain three elements with JSON null at index 1
- **AND** the analytics endpoint should receive no events
