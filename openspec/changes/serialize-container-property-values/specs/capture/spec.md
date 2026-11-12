## ADDED Requirements

### Requirement: Capture serializes set-like and listed sequence property values as arrays

When the SDK serializes a captured event for wire delivery or a disk-backed event queue, a custom property value in one of the following categories SHALL serialize as a JSON array of its elements. The SDK MUST NOT serialize such a value as an empty object, as JSON `null`, or as a string representation of the container, and MUST NOT drop the property or the event because of it.

1. **Set-like values**: the runtime's built-in set types. The order of the serialized elements is not specified.
2. **Listed ordered sequences**: the finite built-in sequence types listed below for each runtime, other than the native array or list. The serialized elements SHALL keep the sequence's iteration order.

| Runtime | Set-like types | Listed ordered sequences |
| --- | --- | --- |
| Python | `set`, `frozenset` | `tuple`, `collections.deque` |
| JavaScript / TypeScript | `Set` | none |
| Ruby | `Set` | none |
| Swift / Objective-C | `Set`, `NSSet` | none |
| Kotlin / Java | `Set` implementations | `java.util.Queue` and `java.util.Deque` implementations that are not a `List` |
| C# (.NET, Unity) | `ISet<T>` implementations, including `HashSet<T>`, `SortedSet<T>` and `ImmutableHashSet<T>` | `Queue<T>`, `LinkedList<T>` |
| Dart | `Set` | `Queue` |
| Elixir | `MapSet` | none |
| PHP | none | `SplFixedArray`, `SplDoublyLinkedList` and `SplQueue` (not `SplStack`) |
| Rust | `HashSet`, `BTreeSet` | `VecDeque` |
| GDScript (Godot) | none | `PackedInt32Array`, `PackedInt64Array`, `PackedFloat32Array`, `PackedFloat64Array`, `PackedStringArray` |
| Go, C++ (Unreal) | none | none |

A runtime that is not listed SHALL apply category 1 to its built-in set types and MAY treat category 2 as empty until the table lists it.

Each element SHALL be serialized as an array element, so nested values follow the same rules as other property values, including the null-valued object property rule. The rule SHALL apply recursively, including to category values nested in objects or arrays.

This is a serialization rule. It does not require an SDK's public property types to accept these values. It does not define the serialization of keyed containers other than plain objects/maps (for example JavaScript `Map`), byte containers (for example Python `bytes`, JavaScript `Uint8Array`, Swift `Data`, Godot `PackedByteArray`), lazy or one-shot iterables (for example generators, iterators, Python `range`, Dart lazy `Iterable`, Kotlin `Sequence`), order-defined collections not in the table (for example .NET `Stack<T>`), or containers that the runtime represents as plain tuples (for example Erlang `:queue` and `:gb_sets`).

#### Scenario: A one-element set-like property value serializes as an array (@both)
- **GIVEN** an initialized SDK whose runtime has a set-like type in the table, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Set Property" and a custom property "tags" whose value is that set-like type containing only the string "a"
- **AND** the SDK is flushed
- **THEN** one event named "Set Property" should be received
- **AND** its custom property "tags" should equal JSON `["a"]`

#### Scenario: A multi-element set-like property value keeps every element (@both)
- **GIVEN** an initialized SDK whose runtime has a set-like type in the table, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Set Property" and a custom property "tags" whose value is that set-like type containing the strings "a", "b" and "c"
- **AND** the SDK is flushed
- **THEN** one event named "Set Property" should be received
- **AND** its custom property "tags" should be a JSON array with exactly the elements "a", "b" and "c" in any order

#### Scenario: A listed ordered sequence property value keeps its order (@both)
- **GIVEN** an initialized SDK whose runtime has a listed ordered sequence type in the table, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Sequence Property" and a custom property "steps" whose value is that sequence type containing 3, 1 and 2 in that order
- **AND** the SDK is flushed
- **THEN** one event named "Sequence Property" should be received
- **AND** its custom property "steps" should equal JSON `[3,1,2]`

#### Scenario: Nested set-like values are converted alongside null-property cleanup (@both)
- **GIVEN** an initialized SDK whose runtime has a set-like type in the table, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nested Set" and a custom property "outer" whose value is an array containing one object with member "inner" set to that set-like type containing only the string "a" and member "drop" set to null
- **AND** the SDK is flushed
- **THEN** one event named "Nested Set" should be received
- **AND** its custom property "outer" should equal JSON `[{"inner":["a"]}]`
