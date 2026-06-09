# Unregister Specification

## Purpose

`unregister` removes a previously-registered **super property** so the SDK stops automatically attaching it to future events.

It is the inverse of `register`: instead of adding persistent event context, it deletes one key from the persistent super-properties store.

`unregister` is a **local state mutation**. It does not emit an event or perform network I/O by itself.

## Applicability

`client` — this is a client-side state API. Server SDKs are stateless per call and generally do not expose a comparable persistent super-properties registry.

## Public signatures

### Canonical client signature

```ts
unregister(property: string): void | Promise<void>
```

### Surface variants

- **posthog-js core / browser:** `unregister(property)`
- **react-native:** `unregister(property): Promise<void>`
- **iOS:** `unregister(key: String)`
- **Android:** `unregister(key: String)`
- **Flutter:** `unregister(key): Future<void>`
- **Unity:** `Unregister(key)` static method

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op rather than forcing work or throwing.
2. **Resolve the target key.** The caller provides the name of the registered/super property to remove.
3. **Remove the key from persistent super properties.**
   - If the key exists, delete it from the stored super-properties map.
   - If the key does not exist, the operation is effectively a no-op.
4. **Persist locally.** Save the updated super-properties map back to local storage.
5. **Do not emit an event.** `unregister` only changes local context.
6. **Affect future event enrichment.** Subsequent events no longer include the removed property unless the caller passes it explicitly on the event or re-registers it later.
7. **Notify local integrations if applicable.** Some SDKs notify local observers / integrations that context changed after unregister.

## State & lifecycle

### State read

- existing persisted super properties
- SDK enabled / initialization state

### State written

- persistent super-properties storage

### Lifecycle behavior

- The removal persists across app restarts.
- Removing a property does not affect already-enqueued events; it only changes future enrichment.
- `reset()` also clears registered properties wholesale; `unregister(...)` is the single-key variant.
- In JS-core-based SDKs, session-only properties (`registerForSession`) are separate and are not affected by persistent `unregister(...)` unless a dedicated session-unregister API is used.

## Error handling

- `unregister` should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Removing a non-existent key is not treated as an error.
- Promise-returning variants resolve after local mutation; they are not waiting on transport.

## Concurrency & ordering guarantees

- Reads/writes of super properties are serialized by the SDK's normal storage / locking model.
- A `capture(...)` call issued after `unregister(...)` completes observes the property as absent.
- If `unregister(...)` races with `capture(...)`, callers observe either the pre-removal or post-removal super-properties set depending on ordering; no partial state is exposed.

## Interactions

- **`register`** — the inverse operation; a later register with the same key reintroduces the property.
- **`capture`** — future capture calls stop receiving the removed property automatically.
- **`identify` / `alias` / `group`** — these APIs also pass through standard event enrichment in audited client SDKs, so the removed property stops appearing there too.
- **`reset`** — clears all registered properties, making `unregister(...)` unnecessary when the caller wants a full context wipe.
- **Session-only property APIs** — separate from persistent unregister semantics.

## Requirements

### Requirement: Canonical unregister behavior

The SDK SHALL implement the canonical `unregister` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Unregister removes a super property from future events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property | value |
  | plan     | pro   |
  | region   | eu    |
- **WHEN** unregister is called for property "plan"
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** the enqueued event should not include property "plan"
- **AND** the enqueued event property "region" should equal "eu"

#### Scenario: Unregister persists removal
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered property "plan" is "pro"
- **WHEN** unregister is called for property "plan"
- **AND** the SDK is restarted
- **AND** capture is called with event "Loaded"
- **THEN** the enqueued event should not include property "plan"

#### Scenario: Unregister missing property is a no-op
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** unregister is called for property "missing"
- **THEN** the call should not throw
- **AND** registered properties should remain unchanged
