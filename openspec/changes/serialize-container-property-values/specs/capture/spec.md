## ADDED Requirements

### Requirement: Capture serializes set-like and sequence property values as arrays

When the SDK serializes a captured event for wire delivery or a disk-backed event queue, a custom property value of a built-in set-like type (for example Python `set` or `frozenset`, JavaScript `Set`, Ruby `Set`, Swift `Set`, Kotlin/Java `Set`) or a built-in ordered sequence type other than the native array (for example Python `tuple` or `collections.deque`) SHALL serialize as a JSON array of its elements. The SDK MUST NOT serialize such a value as an empty object, as JSON `null`, or as a string representation of the container.

Ordered sequences SHALL keep their element order. The order of elements serialized from a set-like value is not specified. Each element SHALL be serialized as if it were an array element at that position, so nested values follow the same rules as other property values, including the null-valued object property rule. The rule SHALL apply recursively, including to set-like and sequence values nested in objects or arrays.

This is a serialization rule. It does not require an SDK's public property types to accept these containers, and it does not change how the SDK handles keyed containers other than plain objects/maps (for example JavaScript `Map`), lazy or one-shot iterables (for example generators, iterators, or Python `range`), byte strings, or other values with no JSON equivalent.

#### Scenario: A one-element set-like property value serializes as an array (@both)
- **GIVEN** an initialized SDK whose runtime has a built-in set-like type, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Set Property" and a custom property "tags" whose value is a set-like value containing only the string "a"
- **AND** the SDK is flushed
- **THEN** one event named "Set Property" should be received
- **AND** its custom property "tags" should equal JSON `["a"]`

#### Scenario: A multi-element set-like property value keeps every element (@both)
- **GIVEN** an initialized SDK whose runtime has a built-in set-like type, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Set Property" and a custom property "tags" whose value is a set-like value containing the strings "a", "b" and "c"
- **AND** the SDK is flushed
- **THEN** one event named "Set Property" should be received
- **AND** its custom property "tags" should be a JSON array with exactly the elements "a", "b" and "c" in any order

#### Scenario: An ordered sequence property value keeps its order (@both)
- **GIVEN** an initialized SDK whose runtime has a built-in ordered sequence type other than the native array, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Sequence Property" and a custom property "steps" whose value is that sequence type containing 3, 1 and 2 in that order
- **AND** the SDK is flushed
- **THEN** one event named "Sequence Property" should be received
- **AND** its custom property "steps" should equal JSON `[3,1,2]`

#### Scenario: Nested set-like values are converted and their elements cleaned (@both)
- **GIVEN** an initialized SDK whose runtime has a built-in set-like type, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nested Set" and a custom property "outer" whose value is an object with member "inner" set to a set-like value containing only an object represented by JSON `{"keep":1,"drop":null}`
- **AND** the SDK is flushed
- **THEN** one event named "Nested Set" should be received
- **AND** its custom property "outer" should equal JSON `{"inner":[{"keep":1}]}`
