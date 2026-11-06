## Why

Capture v1 answers a 2xx with a per-event `results` map keyed by the **canonical
lowercase hyphenated** uuid, while the endpoint itself parses an incoming event
uuid leniently (uppercase, unhyphenated, brace-wrapped, `urn:uuid:`-prefixed).
An SDK that sends a caller-supplied uuid unchanged therefore cannot find its own
events in the response: a `retry` verdict is never retried, a `drop` verdict
never reaches the error callback, and the event is silently treated as accepted.

Two server SDKs have now fixed this the same way:

- posthog-go [#358](https://github.com/PostHog/posthog-go/pull/358) — `makeUUID`
  returns the canonical form of a valid caller-supplied uuid, and
  `prepareForSend` canonicalizes the correlation key again after `BeforeSend`.
- posthog-python [#1022's series, #1020](https://github.com/PostHog/posthog-python/pull/1020)
  — `_stringify_event_uuid` stores the canonical form ("because capture keys
  per-event results by it"), re-run after `before_send` "so the returned uuid
  always matches the wire event".

Both also fall back to a freshly generated UUIDv7 when the caller's value does
not parse, rather than failing the capture call.

The `capture` spec says only that `uuid` is a "caller override or a freshly
generated UUIDv7". It does not say the value on the wire is canonical, that the
returned uuid matches it, or what happens to an unparseable override — so a new
SDK (or the next one to move to Capture v1) can reintroduce exactly the
correlation bug both SDKs just fixed.

## What Changes

- Add a `capture` requirement: the event uuid is sent in canonical lowercase
  hyphenated form, a caller-supplied uuid in another accepted form is normalized
  before enqueue, the returned uuid is the normalized value, normalization runs
  after the before-send hook, and an unparseable override is replaced with a
  generated UUIDv7 instead of failing the call.
- Note in the narrative (Behavior step 5, step 8, Error handling) why the
  canonical form matters: Capture v1 keys its per-event results by it.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: require a canonical event uuid on the wire and define how a
  non-canonical or unparseable caller override is handled.

## Impact

Only SDKs that accept a caller-supplied event uuid are affected, and the change
is observable only in the serialized uuid and the capture return value — no
public signature changes. SDKs that type the uuid (posthog-rs uses a typed
`Uuid`, which always serializes canonically) already conform. SDKs still on the
legacy `/batch/` wire are unaffected in practice, since the canonical form is
accepted everywhere; they conform once they normalize.
