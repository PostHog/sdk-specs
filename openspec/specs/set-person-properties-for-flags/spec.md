# Set Person Properties For Flags Specification

## Purpose

`set-person-properties-for-flags` stores **local person-property overrides** that the SDK should include in future feature-flag evaluation requests.

It exists to solve the common race where:

- the app has just learned new person properties locally
- the backend has not processed a corresponding `identify` / `$set` event yet
- flag evaluation needs those properties immediately

This API is a **local feature-flag evaluation helper**. It does not write person properties to PostHog by itself; it updates the client-side flag-evaluation context.

## Applicability

`client` — this is a client-side flag-context API. Server SDKs usually take person properties directly on each flag-evaluation call instead of maintaining a persistent local override store.

## Public signatures

### Canonical client signature

```ts
setPersonPropertiesForFlags(
  properties: Record<string, JsonValue>,
  reloadFeatureFlags?: boolean,
): void
```

### Surface variants

- **posthog-js core / react-native:** `setPersonPropertiesForFlags(properties, reloadFeatureFlags = true)`
- **browser:** `setPersonPropertiesForFlags(properties, reloadFeatureFlags = true)`
- **iOS:**
  - `setPersonPropertiesForFlags(_ properties: [String: Any])`
  - `setPersonPropertiesForFlags(_ properties: [String: Any], reloadFeatureFlags: Bool = true)`
- **Android:** `setPersonPropertiesForFlags(userProperties: Map<String, Any>, reloadFeatureFlags: Boolean = true)`
- **Unity:** `SetPersonPropertiesForFlags(Dictionary<string, object> properties, bool reloadFeatureFlags = true)`

Some implementations also expose a separate `resetPersonPropertiesForFlags(...)` API to clear the same local override store.

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs do nothing.
2. **Validate input.** Empty or invalid property maps are ignored.
3. **Merge into the local person-properties-for-flags cache.**
   - Successive calls are additive.
   - If the same key already exists, the new value overwrites it.
   - In js-core-based implementations, callers may also pass `$set_once`-style nested input, which applies set-once semantics for keys that do not already exist.
4. **Persist locally.** The updated cache is written to client storage so it survives restarts.
5. **Optionally reload feature flags immediately.** When `reloadFeatureFlags` is `true` (the default), the SDK refreshes flags after updating the cache.
6. **Do not emit an analytics event.** This API only changes the local evaluation context.
7. **Affect subsequent flag evaluation.** Future `reload-feature-flags`, automatic flag reloads, and other client flag-evaluation paths use the cached person properties until they are reset or overwritten.

## State & lifecycle

### State read

- existing person-properties-for-flags cache
- SDK enabled / initialization state
- reload-feature-flags configuration/state

### State written

- persistent person-properties-for-flags cache
- in-memory mirror of that cache
- optionally, freshly reloaded feature-flag cache

### Lifecycle behavior

- The cached person-properties-for-flags overrides persist across app restarts.
- `identify(...)` may also update this cache automatically in some SDKs.
- `reset()` clears these locally cached flag-evaluation person properties in the audited mobile/client SDKs.
- `resetPersonPropertiesForFlags(...)` clears only this override store without resetting the whole SDK identity.

## Error handling

- This API should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Empty or invalid property maps are ignored.
- Storage failures are typically logged/swallowed by the SDK's persistence layer.
- Feature-flag reload failures after the write do not roll back the local cache update.

## Concurrency & ordering guarantees

- Person-properties-for-flags reads/writes are serialized by the SDK's normal storage / locking model.
- A flag reload triggered after the call observes the newly-updated cache.
- If this API races with `reload-feature-flags`, callers may observe either the pre-update or post-update flag context depending on ordering; no partial property merge is exposed.

## Interactions

- **`reload-feature-flags`** — commonly triggered immediately after this API updates the local cache.
- **`identify`** — some SDKs automatically feed newly identified person properties into the same cache.
- **`set-group-properties-for-flags`** — sibling API for local group-property overrides.
- **`resetPersonPropertiesForFlags`** — clears only this cache.
- **`reset`** — clears this cache along with broader user-scoped client state.
- **Feature-flag getters/evaluators** — subsequent flag evaluation requests consume these cached overrides.

## Requirements

### Requirement: Canonical set-person-properties-for-flags behavior

The SDK SHALL implement the canonical `set-person-properties-for-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Set person properties stores overrides for future flag evaluation (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** set person properties for flags is called with properties:
  | property | value |
  | plan     | pro   |
- **THEN** person properties for flags should include:
  | property | value |
  | plan     | pro   |

#### Scenario: Person property overrides are sent with flag reloads (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** person properties for flags are:
  | property | value |
  | plan     | pro   |
- **WHEN** reload feature flags is called
- **THEN** the feature flag request should include person property "plan" with value "pro"
