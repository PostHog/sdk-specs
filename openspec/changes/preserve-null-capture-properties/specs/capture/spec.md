## ADDED Requirements

### Requirement: Explicit null capture properties are valid JSON data

The SDK SHALL accept explicit null-valued custom event properties using a platform-idiomatic JSON null representation (for example Python `None`, JavaScript `null`, or Swift `NSNull()`). It SHALL preserve those values as JSON `null` through event preparation, queueing, and wire serialization rather than rejecting the event, removing the key, or converting the value to a string solely because it is null. This applies recursively to nested objects and arrays; null array elements MUST retain their positions. Queued and immediate/synchronous capture variants SHALL follow the same rule.

An explicitly present null-valued key is distinct from an absent key. The SDK MUST NOT insert null-valued keys for missing caller properties. JavaScript object properties containing `undefined` MAY remain omitted according to normal JSON serialization; `undefined` is not an explicit JSON null.

This requirement concerns custom event property values, not a missing/null properties container, required envelope fields, or reserved fields with their own type/validation contracts. Existing enrichment precedence, consent gates, and caller-configured filtering or `before_send` mutations/drops remain authoritative. Without such an explicit filter or a field-specific rule, null alone MUST NOT trigger sanitization. The OTLP null-attribute omission requirements for logs and traces are unchanged.

#### Scenario: Queued capture preserves nulls on the wire (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"optional":null,"nested":{"value":null},"items":["first",null,"last"],"empty":"","zero":0,"enabled":false}`
- **AND** the SDK is flushed
- **THEN** the received event should contain every supplied custom property with the same JSON value
- **AND** "optional" and "nested.value" should be present with JSON null values, not the string "null"
- **AND** "items" should contain three elements with JSON null at index 1
- **AND** the absent custom property "missing" should remain absent

#### Scenario: Immediate capture preserves nulls on the wire (@both)
- **GIVEN** an initialized SDK supporting immediate delivery with a valid distinct id and no property-changing hooks or filters
- **AND** capture is configured for immediate delivery
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"optional":null,"nested":{"value":null},"items":["first",null,"last"]}`
- **AND** the immediate send completes
- **THEN** the received event should contain every supplied custom property with the same JSON value
- **AND** "items" should contain three elements with JSON null at index 1

#### Scenario: JavaScript object undefined remains distinct from null (@both)
- **GIVEN** an initialized JavaScript SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Absent Versus Null" and properties `{ optional: null, missing: undefined }`
- **AND** the SDK is flushed
- **THEN** the received event property "optional" should be present with JSON null
- **AND** the received event properties should not contain "missing"
