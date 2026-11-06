## ADDED Requirements

### Requirement: Fatal exception payloads keep their exception data

A separate fatal-path exception serializer SHALL emit the same SDK-owned exception data as the
handled path would for the same exception: every `$exception_list` entry it was given, each with
its `stacktrace` and frames. Capture-boundary metadata that `exception-event-metadata` sets
per boundary, such as the outermost `mechanism.handled` and `mechanism.type`, is not part of this
parity and follows that capability. This applies where an SDK builds the `$exception` event for a
fatal or crash boundary through a different serializer than the one handled exceptions go through —
typically a size-bounded, strictly JSON-safe payload handed to a native layer that persists it
synchronously inside the dying process.

An optional field whose value is unset SHALL be omitted from the serialized event, the way JSON
serialization omits an absent object member. It SHALL NOT make its containing object
unserializable, and SHALL NOT cause that object or any object containing it — the frame, the
`stacktrace`, or the `$exception_list` entry — to be dropped. A stack frame's `chunk_id` is the
common case: it is unset for any frame whose file has no chunk ID, and such a frame SHALL still be
serialized, without `chunk_id`.

Where the serializer enforces a size budget, `$exception_list` SHOULD be budgeted separately from
caller-supplied custom properties, so a large property set cannot evict the exception data.
Truncating within the exception data to fit that budget — dropping trailing frames, trailing chained
`$exception_list` entries under the limits in `exception-event-metadata`, or a `stacktrace` that
alone exceeds the budget — stays allowed; the rules above forbid dropping data only for being
unset, not for size.

#### Scenario: An unset optional frame field does not drop the stack trace
- **GIVEN** an SDK whose fatal path serializes the exception payload separately
- **AND** a fatal exception whose stack has a frame with no chunk ID
- **WHEN** the fatal `$exception` event is built
- **THEN** the event's `$exception_list` entry retains its `stacktrace` with every frame
- **AND** the frame with no chunk ID carries no `chunk_id` key on the wire

#### Scenario: The fatal path reports the same exception data as the handled path
- **GIVEN** an SDK whose fatal path serializes the exception payload separately
- **WHEN** the same exception is reported once as fatal and once as handled
- **THEN** both `$exception` events carry the same `$exception_list` entries, each with its
  `stacktrace` and frames, apart from the outermost entry's boundary-specific `mechanism` fields
- **AND** neither event is delivered with only `type`, `value` and `mechanism`

#### Scenario: Custom properties cannot evict the exception data
- **GIVEN** an SDK whose fatal payload is bounded by a size budget
- **AND** caller-supplied custom properties large enough to fill that budget on their own
- **WHEN** the fatal `$exception` event is built
- **THEN** the `$exception_list` entries are retained
- **AND** the custom properties are the data dropped to stay within the budget
