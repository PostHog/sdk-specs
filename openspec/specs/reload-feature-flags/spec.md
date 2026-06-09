# Reload Feature Flags Specification

## Purpose

`reload-feature-flags` refreshes the SDK's cached feature-flag values from PostHog using the client's **current identity and context**.

It is the manual "fetch the latest flags now" API. Client SDKs also invoke it implicitly after operations that affect flag evaluation, such as `identify(...)`, `group(...)`, `reset()`, or changes to person/group properties for flags.

## Applicability

`client` — this is primarily a client-side cache-refresh API. Server SDKs usually expose direct flag-evaluation methods rather than a persistent ambient flag cache reload primitive.

## Public signatures

### Canonical client signature

```ts
reloadFeatureFlags(callback?: (flags?: Record<string, boolean | string>, error?: Error) => void): void | Promise<void>
```

### Surface variants

- **posthog-js core / browser:** `reloadFeatureFlags(options?: { cb?: (err?: Error, flags?: FeatureFlags) => void }): void`
- **flutter:** `reloadFeatureFlags(): Future<void>`
- **react-native:**
  - `reloadFeatureFlags(): void`
  - `reloadFeatureFlagsAsync(): Promise<Record<string, boolean | string> | undefined>`
- **iOS:**
  - `reloadFeatureFlags()`
  - `reloadFeatureFlags(_ callback: @escaping () -> Void)`
- **Android:** `reloadFeatureFlags(onFeatureFlags: PostHogOnFeatureFlags? = null): void`
- **Unity:** `ReloadFeatureFlagsAsync(): Task`

## Behavior

1. **Guard / no-op if unavailable.** Disabled or unavailable SDK instances do nothing.
2. **Read the current flag-evaluation context.** The reload uses the client's current:
   - `distinct_id`
   - anonymous id (when relevant and `reuseAnonymousId` is false)
   - current `$groups`
   - cached person properties for flags
   - cached group properties for flags
   - device id where the SDK supports device-based flag bucketing
3. **Issue a feature-flags request to PostHog.** The SDK fetches fresh flag values from the server using the current context.
4. **Update the local cache.** Successful responses replace or merge the locally-cached flag values, payloads, request metadata, and related remote-config-derived state.
5. **Notify listeners / callbacks.**
   - Callback-based APIs invoke the provided completion callback once the reload cycle finishes.
   - Event/listener systems (for example js-core `onFeatureFlags(...)`) are notified after the new values are persisted.
6. **Return immediately or as an async handle.**
   - `void` APIs fire-and-forget.
   - Promise/Task APIs resolve when the current reload cycle completes.
7. **Do not emit analytics events directly.** Reloading flags itself does not send a capture event, though later feature-flag access may emit `$feature_flag_called` depending on SDK/configuration.

## State & lifecycle

### State read

- current distinct id / anonymous id
- ambient groups
- person properties for flags
- group properties for flags
- existing cached flags / payloads / remote config

### State written

- cached feature flags
- cached feature flag payloads / metadata
- internal "flags loaded" / in-flight state
- related remote-config-controlled caches where the SDK couples them to flags

### Lifecycle behavior

- Reload is automatically triggered by several identity/context-changing APIs in audited client SDKs (`identify`, `group`, `reset`, person/group-properties-for-flags setters).
- Manual reload lets callers force a refresh when they need fresh flag values immediately.
- The API uses the **current** ambient identity/context at call time, not a caller-specified override.

## Error handling

- Reload should not throw in normal operation.
- Failure is surfaced via callback error parameters, logs, or an unresolved/empty result depending on SDK.
- If the network is unavailable, SDKs typically keep existing cached flags and invoke completion callbacks without crashing.
- Quota-limited or partial-computation responses may leave cached flags partially unchanged rather than clearing everything.

## Concurrency & ordering guarantees

- SDKs generally deduplicate or serialize concurrent reloads.
- js-core and Android explicitly queue one pending reload if another reload is already in flight so identity-sensitive requests are not lost.
- Unity queues callbacks while a load is already running and resolves them when the in-flight request completes.
- Callers should treat the cache as updated only after the callback fires or the returned Promise/Task resolves.

## Interactions

- **`identify`** — typically triggers a flag reload because user identity and cohorts may have changed.
- **`group`** — typically triggers a reload when group membership changes.
- **`reset`** — reloads flags for the now-anonymous user.
- **`setPersonPropertiesForFlags` / `setGroupPropertiesForFlags`** — commonly call reload so local flag evaluation reflects the new override properties immediately.
- **`is-feature-enabled` / `get-feature-flag` / `get-feature-flag-payload`** — read from the cache that this method refreshes.
- **`onFeatureFlags` / equivalent listeners** — notified after a successful cache update in SDKs that expose them.

## Requirements

### Requirement: Canonical reload-feature-flags behavior

The SDK SHALL implement the canonical `reload-feature-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Reload feature flags fetches flags for the current identity
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **AND** the mock server will return feature flags:
  | key     | value |
  | beta-ui | true  |
- **WHEN** reload feature flags is called
- **THEN** the mock server should receive a feature flag request for distinct id "user-123"
- **AND** cached feature flags should be:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Reload includes group and property override context
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** group context contains type "company" and key "company-123"
- **AND** person properties for flags are:
  | property | value |
  | plan     | pro   |
- **WHEN** reload feature flags is called
- **THEN** the feature flag request should include group "company" with key "company-123"
- **AND** the feature flag request should include person property "plan" with value "pro"

#### Scenario: Reload failure keeps existing cached flags
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the mock server will fail the next feature flag request with status 503
- **WHEN** reload feature flags is called
- **THEN** cached feature flags should still include:
  | key     | value |
  | beta-ui | true  |
- **AND** the call should not throw
