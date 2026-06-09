# On Feature Flags Specification

## Purpose

`on-feature-flags` registers a callback/listener that is invoked when **feature flags become available or are updated**.

It is the public notification surface for "flags are ready, reload your UI / re-read flag values now" behavior.

This API does **not** itself fetch flags or evaluate them; it subscribes to the results of the SDK's existing feature-flag loading flow.

## Applicability

`client` — this is a client-side callback/event surface tied to ambient feature-flag state.

## Public signatures

### Canonical client signature

```ts
onFeatureFlags(
  callback: (context?: {
    flags?: string[]
    variants?: Record<string, string | boolean>
    errorsLoading?: boolean
  }) => void
): Unsubscribe | void
```

The exact callback shape varies by SDK:

- some pass the loaded flag keys and/or variants directly
- some expose only a no-argument "flags are ready" signal and require callers to read values via getter APIs
- some return an unsubscribe function, while others use config-time callback fields or event subscription syntax instead

### Surface variants

- **browser:** `onFeatureFlags(callback): () => void`
- **js-core / react-native:** `onFeatureFlags(callback): () => void` with a simpler callback that receives the latest `featureFlags` map/list
- **Android:** `PostHogConfig.onFeatureFlags = callback` and `reloadFeatureFlags(onFeatureFlags?)`
- **Flutter:** `PostHogConfig(onFeatureFlags: ...)` / `config.onFeatureFlags = ...` during `setup(...)`
- **Unity:** `PostHogConfig.OnFeatureFlagsLoaded = Action` and static event `PostHog.OnFeatureFlagsLoaded += handler`

`on-feature-flags` is used as the canonical name because the majority of audited client surfaces use that phrase directly.

## Behavior

1. **Register a callback/listener with the SDK's feature-flag subsystem.**
   - Method-style APIs return an unsubscribe function.
   - Config/event-style APIs store the callback or attach/remove a handler through event syntax.
2. **Invoke the callback when flags become ready.**
   - This can happen after startup preload, cache hydration, remote reload, identity change, or any other flag refresh path.
3. **Invoke again on subsequent updates.**
   - The callback is not one-shot; it is intended to react to future flag changes as well.
4. **Pass callback data according to SDK style.**
   - Browser passes enabled flag keys, variants, and an optional context like `{ errorsLoading }`.
   - js-core / React Native expose a simpler callback shape centered on the latest feature-flag values.
   - Android, Flutter, and Unity primarily expose a readiness signal with no direct payload; callers re-read flags through getter APIs when notified.
5. **Support immediate invocation when state is already loaded in some SDKs.**
   - Browser calls the callback immediately if flags were already loaded.
   - Other SDKs may instead invoke only on the next load/update cycle.
6. **Do not mutate flags by subscribing.** The callback only observes flag readiness/change notifications.
7. **Handle missing/no-flag cases SDK-specifically.**
   - Some implementations still invoke the callback even when there are no flags or when loading errored, so app code waiting on readiness can continue.

## State & lifecycle

### State read

- current loaded/cached feature-flag state
- registered callback/listener list
- feature-flag loading lifecycle state (`loaded`, updating, errored)

### State written

- callback/listener registrations
- unsubscribe/remove-handler bookkeeping in SDKs that support it

### Lifecycle behavior

- Callbacks can be registered during setup or later at runtime.
- They remain active until explicitly unsubscribed/removed, or until the SDK instance is torn down.
- Startup flag preload paths may trigger the callback early in app lifecycle.
- Cache-driven startups can also trigger the callback before a fresh network reload completes.
- Wrapper SDKs may translate platform-native notifications into their own callback surface. Flutter maps native/browser flag-loaded signals into a Dart `onFeatureFlags` callback set during `setup(...)`.

## Error handling

- Registering the callback should not throw in normal operation.
- Some SDKs catch and log callback exceptions so one failing handler does not break flag loading.
- Uninitialized or missing flag subsystems may call back with an error context or simply return a no-op unsubscribe, depending on SDK.

## Concurrency & ordering guarantees

- Callbacks are invoked after the corresponding flag update/load work has committed enough state for getters to read the new values.
- Ordering between multiple callbacks follows the SDK's own listener/event registration model.
- If flags update rapidly, callbacks may fire multiple times; callers should treat them as change notifications, not exactly-once events.

## Interactions

- **`reload-feature-flags`** — commonly triggers this callback when the refresh completes.
- **feature-flag getter APIs** (`get-feature-flag`, `is-feature-enabled`, etc.) — callers often re-read them inside the callback.
- **setup / remote-config / preload paths** — initial flag loading may invoke the callback automatically.
- **identity-changing APIs** such as `identify(...)` / `group(...)` — in some SDKs these can trigger flag reloads, which then trigger the callback.

## Requirements

### Requirement: Canonical on-feature-flags behavior

The SDK SHALL implement the canonical `on-feature-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Listener is invoked when feature flags are loaded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Listener registered after flags are ready is invoked with current values
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are already loaded with values:
  | key     | value |
  | beta-ui | true  |
- **WHEN** a feature flag listener is registered
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Listener can be unsubscribed
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** the feature flag listener is unsubscribed
- **AND** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should not be invoked again
