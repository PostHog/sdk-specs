## REMOVED Requirements

### Requirement: Exception capture preserves explicit null custom properties

**Reason**: Exception capture follows the revised shared null-property contract.
**Migration**: Omit null-valued custom object members while preserving null array elements without changing SDK-owned exception metadata rules.

## ADDED Requirements

### Requirement: Exception capture drops null-valued custom object properties

`capture_exception` / `captureException` SHALL follow capture's "Capture drops null-valued object properties" requirement for caller-supplied additional custom event properties, including nested objects and objects inside arrays. Null array elements SHALL retain their positions. This MUST NOT change exception-input validation or field-specific rules for SDK-owned exception metadata.

#### Scenario: Exception capture drops null-valued custom properties on the wire (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **AND** a valid handled exception
- **WHEN** capture exception is called for the exception with additional custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2]}`
- **AND** the SDK is flushed
- **THEN** one "$exception" event should be received
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2]}`
- **AND** the event should still include its SDK-generated exception data
