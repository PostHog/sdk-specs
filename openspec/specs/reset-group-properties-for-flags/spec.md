# Reset Group Properties For Flags Specification

## Purpose

`reset-group-properties-for-flags` clears **locally cached group-property overrides** that the SDK includes in future feature-flag evaluation requests.

It is the inverse of `set-group-properties-for-flags`:

- `set-group-properties-for-flags(...)` adds or overwrites local group-property overrides for flag evaluation
- `reset-group-properties-for-flags(...)` removes those overrides so future flag evaluation falls back to server-side group properties only

This API is a **local feature-flag evaluation helper**. It does not emit a `$groupidentify` event and does not delete the group profile in PostHog.

## Applicability

`client` — this is a client-side flag-context API. Server SDKs usually pass group properties directly on each flag-evaluation call instead of maintaining a persistent local override cache.

## Public signatures

### Canonical client signature

```ts
resetGroupPropertiesForFlags(
  groupType?: string,
  reloadFeatureFlags?: boolean,
): void
```

### Surface variants

- **posthog-js core:** `resetGroupPropertiesForFlags()`
- **browser:** `resetGroupPropertiesForFlags(groupType?)`
- **react-native:** `resetGroupPropertiesForFlags(reloadFeatureFlags = true)`
- **iOS:**
  - `resetGroupPropertiesForFlags()`
  - `resetGroupPropertiesForFlags(reloadFeatureFlags: Bool = true)`
  - `resetGroupPropertiesForFlags(_ groupType: String)`
  - `resetGroupPropertiesForFlags(_ groupType: String, reloadFeatureFlags: Bool = true)`
- **Android:** `resetGroupPropertiesForFlags(type: String? = null, reloadFeatureFlags: Boolean = true)`
- **Unity:**
  - `ResetGroupPropertiesForFlags(bool reloadFeatureFlags = true)`
  - `ResetGroupPropertiesForFlags(string groupType, bool reloadFeatureFlags = true)`

Some SDKs only support clearing **all** cached group-property overrides, while others also support clearing a **single group type**.

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs do nothing.
2. **Determine the reset scope.**
   - If no `groupType` is supplied, clear the entire local group-properties-for-flags cache.
   - If `groupType` is supplied, clear only that group's cached overrides when the SDK supports per-group reset.
3. **Persist locally.** Save the updated cache back to local storage so the reset survives restarts.
4. **Optionally reload feature flags immediately.** When `reloadFeatureFlags` is `true` (the default in the mobile/client surfaces that expose it), the SDK refreshes flags after clearing the cache.
5. **Do not emit an analytics event.** This API only changes the local evaluation context.
6. **Affect subsequent flag evaluation.** Future `reload-feature-flags`, automatic flag reloads, and other client flag-evaluation paths stop using the cleared group-property overrides.

## State & lifecycle

### State read

- existing group-properties-for-flags cache
- SDK enabled / initialization state
- reset scope (`groupType` or all groups)
- reload-feature-flags configuration/state

### State written

- persistent group-properties-for-flags cache
- in-memory mirror of that cache
- optionally, freshly reloaded feature-flag cache

### Lifecycle behavior

- Clearing the cache persists across app restarts.
- `group(...)` or `set-group-properties-for-flags(...)` can repopulate the cache later.
- `reset()` also clears these locally cached group-property overrides in the audited mobile/client SDKs.
- On SDKs that support per-group reset, other group types remain intact when one group type is cleared.

## Error handling

- This API should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Clearing a non-existent group type is effectively a no-op.
- Storage failures are typically logged/swallowed by the SDK's persistence layer.
- Feature-flag reload failures after the reset do not restore the cleared cache entries.

## Concurrency & ordering guarantees

- Group-properties-for-flags reads/writes are serialized by the SDK's normal storage / locking model.
- A flag reload triggered after the call observes the cleared cache.
- If this API races with `reload-feature-flags`, callers may observe either the pre-reset or post-reset flag context depending on ordering; no partial clear is exposed.

## Interactions

- **`set-group-properties-for-flags`** — the inverse operation; later calls can repopulate the cleared cache.
- **`reload-feature-flags`** — commonly triggered immediately after this API updates the local cache.
- **`group` / internal `$groupidentify` emission** — some SDKs automatically repopulate the cache when group properties are supplied there.
- **`reset`** — clears this cache along with broader user-scoped client state.
- **Feature-flag getters/evaluators** — subsequent flag evaluation requests stop using the cleared overrides.

## Requirements

### Requirement: Canonical reset-group-properties-for-flags behavior

The SDK SHALL implement the canonical `reset-group-properties-for-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Reset group properties clears all local group flag overrides (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** group properties for flags are:
  | group_type | group_key   | property | value |
  | company    | company-123 | plan     | pro   |
- **WHEN** reset group properties for flags is called
- **THEN** group properties for flags should be empty

#### Scenario: Reset group properties affects subsequent flag evaluations (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** group properties for flags are:
  | group_type | group_key   | property | value |
  | company    | company-123 | plan     | pro   |
- **WHEN** reset group properties for flags is called
- **AND** reload feature flags is called
- **THEN** the feature flag request should not include group property "plan"
