## ADDED Requirements

### Requirement: Exception capture preserves explicit null custom properties

`capture_exception` / `captureException` SHALL follow capture's "Explicit null capture properties are valid JSON data" requirement for caller-supplied additional custom event properties, including nested object values and array elements. This MUST NOT change exception-input validation or the field-specific omission rules for SDK-owned exception metadata.

#### Scenario: Exception capture preserves null custom properties on the wire (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **AND** a valid handled exception
- **WHEN** capture exception is called for the exception with additional custom properties represented by JSON `{"optional":null,"nested":{"value":null},"items":["first",null,"last"]}`
- **AND** the SDK is flushed
- **THEN** one "$exception" event should be received
- **AND** the received event should contain every supplied custom property with the same JSON value
- **AND** "items" should contain three elements with JSON null at index 1
- **AND** the event should still include its SDK-generated exception data
