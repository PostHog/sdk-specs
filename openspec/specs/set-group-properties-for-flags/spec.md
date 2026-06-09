# Set Group Properties For Flags Specification

## Purpose

`set-group-properties-for-flags` stores **local group-property overrides** that the SDK should include in future feature-flag evaluation requests.

It exists to solve the common race where:

- the app has just learned new group properties locally
- the backend has not processed a corresponding `$groupidentify` event yet
- flag evaluation needs those group properties immediately

This API is a **local feature-flag evaluation helper**. It does not update the group profile in PostHog by itself; it updates the client-side flag-evaluation context.

## Applicability

`client` — this is a client-side flag-context API. Server SDKs usually take group properties directly on each flag-evaluation call instead of maintaining a persistent local override cache.

## Public signatures

### Canonical client signature

```ts
setGroupPropertiesForFlags(
  groupType: string,
  properties: Record<string, JsonValue>,
  reloadFeatureFlags?: boolean,
): void
```

### Surface variants

- **browser:** `setGroupPropertiesForFlags(propertiesByGroupType, reloadFeatureFlags = true)`
- **iOS:**
  - `setGroupPropertiesForFlags(_ groupType: String, properties: [String: Any])`
  - `setGroupPropertiesForFlags(_ groupType: String, properties: [String: Any], reloadFeatureFlags: Bool = true)`
- **Android:** `setGroupPropertiesForFlags(type: String, groupProperties: Map<String, Any>, reloadFeatureFlags: Boolean = true)`
- **Unity:** `SetGroupPropertiesForFlags(string groupType, Dictionary<string, object> properties, bool reloadFeatureFlags = true)`
- **posthog-js core / react-native:** `setGroupPropertiesForFlags(propertiesByGroupType)` where the argument is a full map of group type → property map; React Native additionally exposes a `reloadFeatureFlags` parameter and performs the reload in the wrapper.

Some implementations also expose a sibling `resetGroupPropertiesForFlags(...)` API to clear all cached group-property overrides or, in some SDKs, a single group type.

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs do nothing.
2. **Validate input.** Empty or invalid property maps are ignored.
3. **Merge into the local group-properties-for-flags cache.**
   - Successive calls are additive.
   - Existing keys for the same group type are overwritten by the new values.
   - Calls for different group types coexist in the same cache.
   - js-core-based variants may update multiple group types in one call.
4. **Persist locally.** The updated cache is written to client storage so it survives restarts.
5. **Optionally reload feature flags immediately.** When `reloadFeatureFlags` is `true` (the default in the mobile/client surfaces that expose it), the SDK refreshes flags after updating the cache.
6. **Do not emit an analytics event.** This API only changes the local evaluation context.
7. **Affect subsequent flag evaluation.** Future `reload-feature-flags`, automatic flag reloads, and other client flag-evaluation paths use the cached group properties until they are reset or overwritten.

## State & lifecycle

### State read

- existing group-properties-for-flags cache
- SDK enabled / initialization state
- reload-feature-flags configuration/state

### State written

- persistent group-properties-for-flags cache
- in-memory mirror of that cache
- optionally, freshly reloaded feature-flag cache

### Lifecycle behavior

- The cached group-properties-for-flags overrides persist across app restarts.
- `group(...)` may also update this cache automatically in some SDKs when group properties are supplied there.
- `reset()` clears these locally cached group-property overrides in the audited mobile/client SDKs.
- `resetGroupPropertiesForFlags(...)` clears only this override store without resetting the whole SDK identity.

## Error handling

- This API should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Empty or invalid property maps are ignored.
- Storage failures are typically logged/swallowed by the SDK's persistence layer.
- Feature-flag reload failures after the write do not roll back the local cache update.

## Concurrency & ordering guarantees

- Group-properties-for-flags reads/writes are serialized by the SDK's normal storage / locking model.
- A flag reload triggered after the call observes the newly-updated cache.
- If this API races with `reload-feature-flags`, callers may observe either the pre-update or post-update flag context depending on ordering; no partial group-property merge is exposed.

## Interactions

- **`reload-feature-flags`** — commonly triggered immediately after this API updates the local cache.
- **`group` / internal `$groupidentify` emission** — some SDKs automatically feed supplied group properties into the same cache when ambient group membership is changed.
- **`set-person-properties-for-flags`** — sibling API for local person-property overrides.
- **`resetGroupPropertiesForFlags`** — clears this cache.
- **`reset`** — clears this cache along with broader user-scoped client state.
- **Feature-flag getters/evaluators** — subsequent flag evaluation requests consume these cached overrides.

## Requirements

### Requirement: Canonical set-group-properties-for-flags behavior

The SDK SHALL implement the canonical `set-group-properties-for-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Set group properties stores overrides for future flag evaluation (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** set group properties for flags is called for group type "company" and group key "company-123" with properties:
  | property | value |
  | plan     | pro   |
- **THEN** group properties for flags should include:
  | group_type | group_key   | property | value |
  | company    | company-123 | plan     | pro   |

#### Scenario: Group property overrides are sent with flag reloads (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** group properties for flags are:
  | group_type | group_key   | property | value |
  | company    | company-123 | plan     | pro   |
- **WHEN** reload feature flags is called
- **THEN** the feature flag request should include group property "plan" with value "pro"
