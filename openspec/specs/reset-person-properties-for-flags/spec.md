# Reset Person Properties For Flags Specification

## Purpose

`reset-person-properties-for-flags` clears **locally cached person-property overrides** that the SDK includes in future feature-flag evaluation requests.

It is the inverse of `set-person-properties-for-flags`:

- `set-person-properties-for-flags(...)` adds or overwrites local person-property overrides for flag evaluation
- `reset-person-properties-for-flags(...)` removes those overrides so future flag evaluation falls back to server-side person properties only

This API is a **local feature-flag evaluation helper**. It does not emit an analytics event and does not delete or mutate the person profile stored in PostHog.

## Applicability

`client` — this is a client-side flag-context API. Server SDKs usually pass person properties directly on each flag-evaluation call instead of maintaining a persistent local override cache.

## Public signatures

### Canonical client signature

```ts
resetPersonPropertiesForFlags(
  reloadFeatureFlags?: boolean,
): void
```

### Surface variants

- **posthog-js core:** `resetPersonPropertiesForFlags()`
- **browser:** `resetPersonPropertiesForFlags()`
- **react-native:** `resetPersonPropertiesForFlags(reloadFeatureFlags = true)`
- **iOS:**
  - `resetPersonPropertiesForFlags()`
  - `resetPersonPropertiesForFlags(reloadFeatureFlags: Bool = true)`
- **Android:** `resetPersonPropertiesForFlags(reloadFeatureFlags: Boolean = true)`
- **Unity:** `ResetPersonPropertiesForFlags(bool reloadFeatureFlags = true)`

The operation is always an **all-person-properties** reset; unlike the group-property helper family, there is no per-key or per-scope variant in the audited SDKs.

## Behavior

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs do nothing.
2. **Clear the local person-properties-for-flags cache.** Remove the entire locally cached override set used for feature-flag evaluation.
3. **Persist locally.** Save the cleared state back to client storage so the reset survives restarts.
4. **Optionally reload feature flags immediately.** In SDK surfaces that expose `reloadFeatureFlags`, `true` is the default and triggers a flag refresh after the cache is cleared. js-core and browser clear the cache without an automatic reload parameter.
5. **Do not emit an analytics event.** This API only changes the local evaluation context.
6. **Affect subsequent flag evaluation.** Future `reload-feature-flags`, automatic flag reloads, and other client flag-evaluation paths stop using previously cached local person-property overrides.

## State & lifecycle

### State read

- SDK enabled / initialization state
- reload-feature-flags configuration/state
- existing person-properties-for-flags cache

### State written

- persistent person-properties-for-flags cache
- in-memory mirror of that cache
- optionally, freshly reloaded feature-flag cache

### Lifecycle behavior

- Clearing the cache persists across app restarts.
- Later `set-person-properties-for-flags(...)` calls can repopulate the cache.
- In audited mobile/client SDKs, `identify(...)` may also repopulate the same cache when person-properties-for-flags mirroring is enabled.
- Full SDK `reset()` implementations typically clear this cache along with broader user-scoped client state.

## Error handling

- This API should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Clearing an already-empty cache is effectively a no-op.
- Storage failures are typically logged/swallowed by the SDK's persistence layer.
- Feature-flag reload failures after the reset do not restore the cleared cache entries.

## Concurrency & ordering guarantees

- Person-properties-for-flags reads/writes are serialized by the SDK's normal storage / locking model.
- A flag reload triggered after the call observes the cleared cache.
- If this API races with `reload-feature-flags`, callers may observe either the pre-reset or post-reset flag context depending on ordering; no partial clear is exposed.

## Interactions

- **`set-person-properties-for-flags`** — the inverse operation; later calls can repopulate the cleared cache.
- **`identify`** — some SDKs automatically feed newly identified person properties into the same cache.
- **`reload-feature-flags`** — commonly triggered immediately after this API updates the local cache.
- **`reset`** — typically clears this cache along with broader identity/session state.
- **Feature-flag getters/evaluators** — subsequent flag evaluation requests stop using the cleared local person-property overrides.

## Requirements

### Requirement: Canonical reset-person-properties-for-flags behavior

The SDK SHALL implement the canonical `reset-person-properties-for-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Reset person properties clears local person flag overrides (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** person properties for flags are:
  | property | value |
  | plan     | pro   |
- **WHEN** reset person properties for flags is called
- **THEN** person properties for flags should be empty

#### Scenario: Reset person properties affects subsequent flag evaluations (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** person properties for flags are:
  | property | value |
  | plan     | pro   |
- **WHEN** reset person properties for flags is called
- **AND** reload feature flags is called
- **THEN** the feature flag request should not include person property "plan"
