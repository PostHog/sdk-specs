## REMOVED Requirements

### Requirement: Explicit null capture properties are valid JSON data

**Reason**: Superseded by the owner's decision to omit null-valued object properties while retaining null array elements.
**Migration**: Drop null-valued object members before sending instead of preserving them. Do not reject the event or compact arrays.

## ADDED Requirements

### Requirement: Capture drops null-valued object properties

The SDK SHALL omit custom event object properties whose values are explicit nulls (for example Python `None`, JavaScript `null`, or Swift `NSNull()`) before sending the event. A null-valued property SHALL NOT cause an otherwise valid event to be rejected, and the SDK MUST NOT send that property as JSON `null` or convert it to the string `"null"`.

This cleanup SHALL apply recursively to nested objects, including objects inside arrays. Null array elements SHALL remain JSON `null` at their original indices; cleanup MUST NOT compact or reorder arrays. Non-null values, including `false`, `0`, empty strings, the literal string `"null"`, and empty objects/arrays, SHALL remain unchanged by this cleanup. Objects made empty by removing null-valued members SHALL remain `{}`, including when they occupy an array slot. If all custom properties are removed, the SDK SHALL still send an otherwise admissible event with its normal SDK metadata.

The same rule SHALL apply to queued and immediate/synchronous capture. It SHALL hold after enrichment and `before_send` processing, including for null-valued custom object members introduced by a hook. JavaScript object properties containing `undefined` SHALL remain omitted under normal JSON serialization, and missing custom keys MUST NOT be synthesized. Caller-configured privacy filtering and event drops remain authoritative; cleanup MUST NOT restore removed data.

This requirement concerns custom event property values, not a missing/null properties container, required envelope fields, or reserved fields with their own type/validation contracts. It does not change those field-specific rules or the OTLP attribute rules for logs and traces.

#### Scenario: Queued capture drops null-valued properties and preserves array positions (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}`
- **AND** the SDK is flushed
- **THEN** one event named "Nullable Properties" should be received
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2,{},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}`
- **AND** the absent custom property "missing" should remain absent

#### Scenario: Immediate capture drops null-valued properties and preserves array positions (@both)
- **GIVEN** an initialized SDK supporting immediate delivery with a valid distinct id and no property-changing hooks or filters
- **AND** capture is configured for immediate delivery
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]]}`
- **AND** the immediate send completes
- **THEN** one event named "Nullable Properties" should be received
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2,{},[null]]}`

#### Scenario: All-null custom properties do not drop the event (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Only Null Properties" and custom properties represented by JSON `{"test":null}`
- **AND** the SDK is flushed
- **THEN** one event named "Only Null Properties" should be received
- **AND** its custom properties should equal JSON `{}`
- **AND** it should retain its normal SDK metadata

#### Scenario: Null object properties introduced by before-send are omitted (@both)
- **GIVEN** an initialized SDK supporting before-send with a valid distinct id
- **AND** before-send adds custom properties represented by JSON `{"hookNull":null,"hookItems":[null,{"drop":null}]}`
- **WHEN** capture is called with event "Hook Properties" and no custom properties
- **AND** the SDK is flushed
- **THEN** one event named "Hook Properties" should be received
- **AND** its custom properties should equal JSON `{"hookItems":[null,{}]}`

#### Scenario: JavaScript null and undefined object properties are omitted (@both)
- **GIVEN** an initialized JavaScript SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Null And Undefined" and JavaScript properties `{ test: null, missing: undefined, items: ["1", null, 2] }`
- **AND** the SDK is flushed
- **THEN** one event named "Null And Undefined" should be received
- **AND** its custom properties should equal JSON `{"items":["1",null,2]}`
