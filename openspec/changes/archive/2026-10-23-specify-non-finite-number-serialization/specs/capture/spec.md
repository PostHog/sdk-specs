## ADDED Requirements

### Requirement: Capture normalizes non-finite numeric property values

JSON has no representation for the non-finite floating-point values NaN, positive infinity and negative infinity. When serializing events for wire delivery or for disk-backed event queues/caches, the SDK SHALL replace a non-finite numeric custom event property value with JSON `null`. The SDK MUST NOT emit the bare tokens `NaN`, `Infinity` or `-Infinity`, which are not valid JSON and are rejected by strict parsers in the ingestion path, and MUST NOT convert the value to the strings `"NaN"`, `"Infinity"` or `"-Infinity"`.

A non-finite value SHALL NOT cost data. It SHALL NOT cause the capture call to be rejected, the event to be dropped, serialization of the batch carrying it to fail, or a healthy neighboring event in the same batch to be lost. If every custom property normalizes away, the SDK SHALL still send an otherwise admissible event with its normal SDK metadata.

This is a serialization rule, not a public API restriction. An SDK whose public capture API already accepts the platform's float or double type SHALL keep accepting non-finite values of that type with the same signatures, and MUST NOT introduce validation errors for them or require callers to pre-filter properties. In-memory event representations MAY retain the original value until serialization, and the SDK MUST NOT mutate the caller's containers while normalizing.

Normalization SHALL apply recursively to nested objects, arrays, and objects inside arrays. A non-finite value occupying an array slot SHALL become JSON `null` at its original index; normalization MUST NOT compact or reorder arrays. For an object member, SDKs currently diverge: most serialize the normalized JSON `null`, while posthog-flutter omits the member so that the result matches **Capture drops null-valued object properties**. This requirement deliberately permits either until that interaction is decided; it is the array-slot and no-data-loss rules that are fixed.

Other values SHALL remain unchanged: finite numbers of any magnitude, including negative zero; booleans; and caller-supplied literal strings such as `"NaN"` or `"Infinity"`, which are ordinary strings and are not normalized. Values of types the SDK's serializer does not support keep their existing error behavior; this rule covers non-finite numbers only.

The same rule SHALL apply to queued and immediate/synchronous capture. The payload SHALL satisfy it after enrichment and `before_send` processing, including for non-finite values a hook introduced. Each disk serialization of a captured event SHALL apply normalization to the event being written, because a persisted record holding `NaN` can be unparseable on restore; normalizing only at network send time is insufficient for SDKs that persist events. Events restored from disk SHALL also satisfy the wire rule. Where an SDK budgets a serialized event or exception step by byte size, it SHALL measure the normalized form, so the buffered and emitted forms agree.

This requirement concerns custom event property values. It does not change reserved or envelope fields that carry their own type and validation contracts, nor the OTLP attribute rules in `logs` and `traces`, which encode a non-finite number as a string instead.

#### Scenario: Non-finite properties neither break the payload nor drop the event (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Non Finite Properties" and custom properties holding float NaN, positive infinity and negative infinity alongside a finite number and the literal string "NaN"
- **AND** capture is called with a second event "Healthy Neighbor" carrying only finite properties
- **AND** the SDK is flushed
- **THEN** the request body should parse under a strict JSON parser that rejects the `NaN` and `Infinity` tokens
- **AND** both events should be received
- **AND** the finite number and the literal string "NaN" should arrive unchanged
- **AND** no received property should hold the string "NaN", "Infinity" or "-Infinity"

#### Scenario: Non-finite array elements become null at their positions (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Non Finite Array" and a custom property whose value is an array of the finite number 1, NaN, the finite number 2, positive infinity, and a nested object holding negative infinity
- **AND** the SDK is flushed
- **THEN** one event named "Non Finite Array" should be received
- **AND** the array should still have five elements in their original order
- **AND** elements 1 and 3 should be JSON `null`
- **AND** elements 0 and 2 should still be 1 and 2

#### Scenario: Caller containers are not mutated (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **AND** the caller holds a reference to the property container it passes to capture
- **WHEN** capture is called with that container holding a non-finite number
- **AND** the SDK is flushed
- **THEN** the event should be received with the value normalized
- **AND** the caller's container should still hold the original non-finite number

#### Scenario: Non-finite values introduced by before-send are normalized (@both)
- **GIVEN** an initialized SDK supporting before-send with a valid distinct id
- **AND** before-send adds a custom property holding NaN
- **WHEN** capture is called with event "Hook Non Finite" and no custom properties
- **AND** the SDK is flushed
- **THEN** one event named "Hook Non Finite" should be received
- **AND** the request body should parse under a strict JSON parser

#### Scenario: Disk-backed serialization normalizes non-finite values (@both)
- **GIVEN** an initialized SDK with disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
- **AND** network delivery is paused
- **WHEN** capture is called with event "Persisted Non Finite" and custom properties holding NaN and positive infinity
- **AND** the SDK serializes the queued event to disk
- **THEN** the persisted record should parse under a strict JSON parser
- **AND** no network request should have been sent
- **WHEN** the persisted event is restored and delivered
- **THEN** one event named "Persisted Non Finite" should be received
