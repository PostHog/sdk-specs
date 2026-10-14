## Why

An SDK that reports fatal crashes often builds the crash `$exception` payload through a second,
stricter serializer than the one handled exceptions go through: the payload is handed to a native
layer that must persist it synchronously inside a dying process, so it is size-bounded and must be
strictly JSON-safe. `capture-exception` says what a `$exception` payload contains and requires a
genuine stack trace to be preserved ("Stack trace preservation over synthesis"), but says nothing
about that second serializer, so nothing stops it from silently emitting *less* than the handled
path for the same exception.

posthog-react-native shipped exactly that bug (PostHog/posthog-js#5287, fixed in
PostHog/posthog-js#5290): its fatal payload builder treated an object member whose value was unset
as making the whole object unserializable. Stack frames routinely carry one — `chunk_id` is unset
for any frame whose file is not in the chunk-id map — so a single frame dropped the entire
`stacktrace`, and fatal crashes reached PostHog with only `type`, `value` and `mechanism`. The same
error captured as handled kept its stack, because that path serializes with ordinary JSON
serialization, which simply omits an absent member.

The contract that was missing is small and platform-independent: an optional field with no value is
absent from the serialized event, not a reason to drop the object it sits on — and whatever a fatal
path does to stay small, it does not cost the exception its stack trace.

## What Changes

- New `capture-exception` requirement **Fatal exception payloads keep their exception data**:
  - A fatal/crash serializer emits the same SDK-owned exception data as the handled path for the
    same exception — every `$exception_list` entry with its `stacktrace` and frames.
  - An optional field whose value is unset is omitted from the serialized event and SHALL NOT make
    its containing object unserializable or cause the frame, the `stacktrace`, or the
    `$exception_list` entry to be dropped.
  - Where the serializer enforces a size budget, `$exception_list` SHOULD be budgeted separately
    from caller-supplied custom properties, so a large property set cannot evict the exception data.
    Truncating *within* the exception data (dropping trailing frames or trailing chained entries)
    stays allowed.
- No change to handled-path behavior, to the wire shape, or to the existing null-valued custom
  property rules.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-exception`: new **Fatal exception payloads keep their exception data** requirement.

## Impact

- **posthog-react-native**: conforms as of PostHog/posthog-js#5290; the bug this requirement
  forbids is the one that fix closed.
- **posthog-ios**, **posthog-android**: capture fatal crashes natively and serialize the payload
  through their normal event serialization; no separate stricter serializer is known to apply, so
  no change is expected.
- **posthog-flutter**: reports managed-runtime errors through the native SDKs, so it inherits their
  behavior.
- **Server SDKs**: no fatal/crash boundary of this shape; unaffected.
- **Acceptance suite**: the scenarios are written in the prose style the "Ignored exception types"
  requirement uses, so no new harness steps are required.
