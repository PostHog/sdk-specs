## ADDED Requirements

### Requirement: Capture drops null-valued object properties

The SDK SHALL omit custom event object properties whose values are explicit nulls (for example Python `None`, JavaScript `null`, or Swift `NSNull()`) or `undefined` where supported by the runtime, when serializing events for wire delivery or disk-backed event queues/caches. A null/undefined-valued property SHALL NOT cause an otherwise valid, previously supported capture call to be rejected. The SDK MUST NOT serialize that object member as JSON `null` or convert its value to the string `"null"` or `"undefined"`.

This is a serialization rule, not a public API restriction. If an SDK's public capture API already accepts null/undefined property values, it SHALL continue accepting them with the same signatures and property value types. Implementations MUST NOT narrow those types, introduce null/undefined input validation errors for previously supported values, or require callers to pre-filter properties to comply. The rule does not require widening APIs that do not currently accept those values. In-memory event representations MAY retain them until serialization. This compatibility rule also applies to the AI and exception capture methods that inherit this requirement.

This cleanup SHALL apply recursively to nested objects, including objects inside arrays. Null array elements SHALL remain JSON `null` at their original indices; cleanup MUST NOT compact or reorder arrays. JavaScript undefined array entries SHALL follow normal JSON serialization as null array elements without changing their positions. Other values, including `false`, `0`, empty strings, the literal strings `"null"` and `"undefined"`, and empty objects/arrays, SHALL remain unchanged by this cleanup. Objects made empty by removing null/undefined-valued members SHALL remain `{}`, including when they occupy an array slot. If all custom properties are removed, the SDK SHALL still send an otherwise admissible event with its normal SDK metadata.

The same rule SHALL apply to queued and immediate/synchronous capture. The wire payload SHALL satisfy it after enrichment and `before_send` processing, including for null/undefined-valued custom object members introduced by a hook. Each disk serialization of a captured event SHALL apply the same object-member cleanup to the event being written; cleanup only at network send time is insufficient for SDKs that persist events. This does not require adding disk persistence or changing hook timing. Events restored from disk SHALL also satisfy the wire serialization rule. Missing custom keys MUST NOT be synthesized. Caller-configured privacy filtering and event drops remain authoritative; cleanup MUST NOT restore removed data.

This requirement concerns custom event property values, not a missing/null properties container, required envelope fields, or reserved fields with their own type/validation contracts. It does not change those field-specific rules, unrelated persistent-storage/cache semantics, or the OTLP attribute rules for logs and traces.

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

#### Scenario: Existing nullable capture inputs remain supported (@both)
- **GIVEN** the SDK's existing public capture API accepts null or undefined property values
- **AND** an existing caller supplies those values using the supported public property types
- **WHEN** the SDK adopts the serialization cleanup rule
- **THEN** the same caller code should remain accepted by the public API, including compilation/type-checking where enforced
- **AND** capture should not reject the call or require caller-side filtering solely because of those values
- **AND** serializing the captured event should omit null/undefined-valued object members while preserving array positions

#### Scenario: Disk-backed event serialization omits null object properties (@both)
- **GIVEN** an initialized SDK with disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
- **AND** network delivery is paused
- **WHEN** capture is called with event "Persisted Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null}]}`
- **AND** the SDK serializes the queued event to disk
- **THEN** the persisted event's decoded custom properties should equal JSON `{"nested":{},"items":["1",null,2,{}]}`
- **AND** no network request should have been sent
- **WHEN** the persisted event is restored and delivered
- **THEN** the received event's custom properties should equal JSON `{"nested":{},"items":["1",null,2,{}]}`

#### Scenario: JavaScript disk serialization omits undefined object members without compacting arrays (@both)
- **GIVEN** an initialized JavaScript SDK with disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
- **AND** network delivery is paused
- **WHEN** capture is called with event "Persisted Undefined" and JavaScript properties `{ test: null, missing: undefined, nested: { missing: undefined }, items: ["1", undefined, null, 2], literal: "undefined" }`
- **AND** the SDK serializes the queued event to disk
- **THEN** the persisted event's decoded custom properties should equal JSON `{"nested":{},"items":["1",null,null,2],"literal":"undefined"}`
- **AND** no network request should have been sent
- **WHEN** the persisted event is restored and delivered
- **THEN** the received event's custom properties should equal JSON `{"nested":{},"items":["1",null,null,2],"literal":"undefined"}`
