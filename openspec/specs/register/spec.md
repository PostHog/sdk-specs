# Register Specification

## Purpose

`register` stores **super properties** (also called registered properties) that the SDK should automatically attach to future events.

It is a client-side convenience API for persistent event context such as app-specific metadata, plan tier, campaign state, or other properties that should be sent repeatedly without being passed on every `capture(...)` call.

`register` is a **local state mutation**. It does not emit an event or perform network I/O by itself.

## Applicability

`client` — this is a client-side state API. Server SDKs are stateless per call and generally do not expose a comparable persistent super-properties registry.

## Public signatures

### Canonical client signature

```ts
register(properties: Record<string, unknown>): void | Promise<void>
```

### Surface variants

```kotlin
// Android / Unity-style key-value variant
register(key: string, value: unknown): void
```

- **posthog-js core / browser:** `register(properties)`
- **react-native:** `register(properties): Promise<void>`
- **iOS:** `register([String: Any])`
- **Android:** `register(key, value)`
- **Flutter:** `register(key, value): Future<void>`
- **Unity:** `Register(key, value)` static method

Despite the surface differences, the semantics are the same: merge new properties into a persistent super-properties store that future events read from.

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op instead of forcing network or throwing.
2. **Validate / sanitize input.** Implementations may reject invalid input (for example empty keys in key-value APIs, non-serializable objects after sanitization, or reserved internal keys).
3. **Merge into stored super properties.**
   - Object-based variants merge the provided property map into the existing stored map.
   - Key-value variants write or overwrite a single property.
   - If the same key already exists, the new value wins.
4. **Persist locally.** The merged super-properties set is written to persistent local storage so it survives app restarts.
5. **Do not emit an event.** `register` only changes local context; it does not enqueue analytics traffic.
6. **Affect future event enrichment.** Subsequent events include the registered properties automatically, unless the caller passes the same key explicitly on the event, in which case the per-event value wins.
7. **Notify local integrations if applicable.** Some SDKs notify local observers / integrations that context changed after register.

## State & lifecycle

### State read

- existing persisted super properties
- SDK enabled / initialization state

### State written

- persistent super-properties storage

### Lifecycle behavior

- Registered properties persist across app restarts.
- Registered properties remain in effect until they are overwritten, removed with `unregister(...)`, or cleared by `reset()`.
- In JS-core-based SDKs, registered properties are distinct from **session-only** properties (`registerForSession(...)`), which are not persisted.

## Error handling

- `register` should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Invalid input is typically dropped or logged rather than raising to the caller.
- Promise-returning variants (for example React Native) resolve once the local mutation path completes; they are not waiting on network because none occurs.

## Concurrency & ordering guarantees

- Super-property reads/writes are serialized by the SDK's normal storage / locking model.
- A `capture(...)` call issued after `register(...)` completes observes the newly-registered properties.
- If `register(...)` races with `capture(...)`, callers observe either the previous or updated super-properties set depending on ordering; no partial merge is exposed.

## Interactions

- **`capture`** — registered properties are merged into future events automatically.
- **`identify` / `alias` / `group`** — these APIs also pass through the standard event-property enrichment path in audited client SDKs, so registered properties are included there as well.
- **`unregister`** — removes one registered property from the same persistent store.
- **`reset`** — clears registered properties along with other user-scoped client state.
- **Session-only property APIs** — where exposed, these are separate from `register` and have different persistence semantics.

## Requirements

### Requirement: Canonical register behavior

The SDK SHALL implement the canonical `register` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Register adds super properties to future events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
  | region   | eu    |
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** the enqueued event properties should include:
  | property | value |
  | plan     | pro   |
  | region   | eu    |

#### Scenario: Later register calls override existing super properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property | value |
  | plan     | free  |
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
- **THEN** registered property "plan" should equal "pro"

#### Scenario: Registered properties persist across SDK initialization
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains registered properties:
  | property | value |
  | plan     | pro   |
- **WHEN** the SDK is initialized with token "test-token"
- **AND** capture is called with event "Loaded"
- **THEN** the enqueued event property "plan" should equal "pro"
