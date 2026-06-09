# Application Lifecycle Specification

## Purpose

Application lifecycle capture is a client-side integration that automatically emits standardized product analytics events when a mobile/game app is installed, updated, opened/foregrounded, or backgrounded. It lets PostHog users measure first launch, version adoption, app opens, and background transitions without manually calling `capture(...)` from platform lifecycle callbacks.

This component is separate from the public `screen(...)` helper and from exception autocapture. It emits normal analytics events through the SDK's capture pipeline.

## Applicability

Client SDKs for native/mobile/game runtimes. It applies to React Native, iOS, Android, Flutter mobile through its native bridges, and Unity. Browser/web and server SDKs do not have a native application install/update/foreground/background lifecycle and are outside this component's canonical scope.

## Configuration surface

Canonical SDKs expose a setup-time boolean option, defaulting to enabled:

```ts
type ClientConfig = {
  captureApplicationLifecycleEvents?: boolean // default: true
}
```

React Native names the option `captureAppLifecycleEvents`, but it controls the same integration. Flutter forwards its Dart `captureApplicationLifecycleEvents` option to the underlying native iOS/Android SDKs. Unity exposes the same concept as `CaptureApplicationLifecycleEvents` on `PostHogConfig` / project settings.

## Behavior

When enabled, the SDK installs platform lifecycle observers during setup and emits these events via the normal `capture(...)` path:

1. **Install/update detection**
   - On startup, read the current app version and build from the platform package/bundle/runtime metadata.
   - Read the previously persisted version/build values from SDK/platform storage.
   - If there is no previously stored build/version marker, emit `Application Installed` with current `version` and/or `build` when available.
   - If the stored build/version marker differs from the current value, emit `Application Updated` with current `version`/`build` plus `previous_version` and/or `previous_build` when available.
   - Persist the current version/build marker after checking so subsequent launches are not reported as fresh installs.
2. **Open/foreground detection**
   - On first launch or foreground transition, emit `Application Opened`.
   - Include a `from_background` boolean where the platform can distinguish cold start from foreground-from-background.
   - Include current `version` and/or `build` on initial open when the platform implementation has those values readily available.
3. **Background detection**
   - On background/stop/pause/focus-loss lifecycle transitions, emit `Application Backgrounded`.
4. **Delivery path**
   - Lifecycle events are ordinary analytics captures: they inherit normal distinct-id, super-property, consent/opt-out, queue, batching, retry, and `beforeSend` behavior unless a wrapper explicitly documents that lifecycle events bypass wrapper-layer hooks.

## State & lifecycle

- The integration is installed as part of SDK setup when lifecycle capture is enabled.
- Install/update state is persisted using the SDK's persistent storage or the platform's local storage (`UserDefaults`, Android preferences, React Native storage, Unity storage).
- Foreground/background state is in memory and is used to suppress duplicate open/background events while already in that state and to populate `from_background`.
- Reset/logout APIs should not erase install/update markers by default, otherwise the next app start could duplicate `Application Installed` / `Application Updated` telemetry.
- Shutdown/close should unregister lifecycle observers where the platform supports explicit observer removal.

## Error handling

Lifecycle observer installation and lifecycle-event emission should not crash the host application. If platform metadata or storage is unavailable, the SDK should skip the affected install/update event or emit the open/background event with fewer properties, and log in debug mode where available.

If lifecycle capture is disabled, lifecycle callbacks may still be observed for other SDK features such as session management or flushing, but no lifecycle analytics events should be emitted.

## Concurrency & ordering guarantees

- Install/update detection should run at most once per process setup cycle, even if multiple setup/lifecycle callbacks occur.
- `Application Installed` or `Application Updated` should be evaluated before or during the initial open lifecycle so install/update telemetry is not delayed until a later foreground transition.
- Background transitions may flush pending events or update the session manager, but lifecycle capture does not guarantee immediate network delivery; it follows the SDK's queue/batcher guarantees.
- Multiple SDK instances or repeated setup/teardown should avoid double-installing lifecycle observers when the underlying platform lifecycle is global.

## Interactions

- **Capture**: lifecycle events are emitted through the normal capture pipeline and should receive standard SDK context and delivery behavior.
- **Persistent storage**: stores previous app version/build markers.
- **Session manager**: foreground/background transitions may start, touch, or end sessions separately from emitting lifecycle analytics.
- **Flush/shutdown**: some platforms flush on background or final quit independently of lifecycle event emission.
- **Before-send hooks**: native-originated lifecycle events may bypass wrapper-layer `beforeSend` hooks when a wrapper delegates lifecycle capture to native SDKs.

## Requirements

### Requirement: Canonical application-lifecycle behavior

The SDK SHALL implement the canonical `application-lifecycle` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: First app start captures install and open events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the platform app version is "1.0.0" and build is "100"
- **WHEN** the application lifecycle integration starts
- **THEN** one event named "Application Installed" should be enqueued
- **AND** one event named "Application Opened" should be enqueued
- **AND** lifecycle storage should remember version "1.0.0" and build "100"

#### Scenario: Version change captures an update event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** lifecycle storage remembers version "1.0.0" and build "100"
- **AND** the platform app version is "1.1.0" and build is "110"
- **WHEN** the application lifecycle integration starts
- **THEN** one event named "Application Updated" should be enqueued
- **AND** the enqueued event properties should include:
  | property         | value |
  | version          | 1.1.0 |
  | build            | 110   |
  | previous_version | 1.0.0 |
  | previous_build   | 100   |

#### Scenario: Background transition captures background event once
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the application is foregrounded
- **WHEN** the application moves to the background
- **THEN** one event named "Application Backgrounded" should be enqueued
- **WHEN** the application moves to the background again
- **THEN** no additional "Application Backgrounded" event should be enqueued

#### Scenario: Disabled lifecycle capture emits no lifecycle analytics events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture disabled
- **WHEN** the application lifecycle integration starts
- **AND** the application moves to the background
- **THEN** no lifecycle analytics events should be enqueued
