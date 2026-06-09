# Debug Specification

## Purpose

`debug` enables or disables the SDK's **verbose internal diagnostic logging** for the current client instance.

It is a local developer-facing control used for troubleshooting SDK behavior. It does **not** capture an analytics event, change identity, or make a network request by itself.

## Applicability

`client` — the audited public runtime `debug(...)` toggle is a client-side SDK surface. Some SDKs expose only configuration-time logging options instead of a public runtime method.

## Public signatures

### Canonical client signature

```ts
debug(enabled?: boolean): void | Promise<void>
```

Where omitted, `enabled` defaults to `true` in the audited js-core, browser, iOS, and Android-style APIs.

### Surface variants

- **posthog-js core / react-native:** `debug(enabled = true): void`
- **browser:** `debug(enabled?): void`
- **iOS:** `debug(_ enabled: Bool = true)`
- **Android:** `debug(enable: Boolean = true)`
- **Flutter:** `debug(enabled: bool): Future<void>`

Some SDKs only expose debug logging through setup/configuration rather than a standalone runtime method.

## Behavior

1. **Guard / no-op if unavailable.** Disabled, uninitialized, or unsupported-platform SDKs generally no-op rather than throwing.
2. **Update local diagnostic logging state.** The SDK enables or disables verbose local logging used for developer troubleshooting.
3. **Do not emit analytics traffic.** Calling `debug(...)` does not enqueue an event or contact PostHog.
4. **Affect future SDK diagnostics only.** The toggle changes how subsequent internal SDK activity is logged; it does not rewrite already-sent data.
5. **Use implementation-specific logging mechanisms.**
   - js-core installs or removes an internal wildcard event listener that logs SDK events/payloads through the SDK logger.
   - Browser routes the toggle through `set_config({ debug })`, which also updates global/browser-side debug state and prints a console banner when toggled.
   - iOS toggles HedgeLog output.
   - Android toggles the config flag consulted by its logger implementation.
   - Flutter forwards the request to the underlying native/browser SDK rather than owning a separate Dart logging backend.
6. **Persist only where the SDK chooses to.** Browser persists its debug flag in local storage (`ph_debug`) so later loads can start in debug mode. Audited native runtime toggles are primarily in-memory for the current configured instance.

## State & lifecycle

### State read

- SDK enabled / initialized state
- current debug/logging state
- setup/configuration state used by the logger implementation
- browser local storage for persisted debug override, where applicable

### State written

- runtime logger/debug toggle state
- browser config/local-storage debug override in SDKs that persist it

### Lifecycle behavior

- Debug mode affects only the current SDK instance unless the implementation persists it.
- Browser can rehydrate debug mode from `ph_debug` local storage on later loads.
- Native SDKs can also start in debug mode when their initial configuration enables it during setup.
- Wrapper SDKs may proxy the lifecycle to another implementation. Flutter forwards runtime `debug(...)` calls to the underlying platform/browser SDK and also serializes `config.debug` during setup.

## Error handling

- `debug(...)` should not throw in normal operation.
- Disabled / unavailable SDKs no-op.
- Promise-returning wrapper surfaces resolve after the local toggle/delegation path finishes; they are not waiting on any network activity.

## Concurrency & ordering guarantees

- Debug toggles are local state mutations and follow the SDK's normal serialization/locking model.
- Internal activity that happens after `debug(true)` completes is eligible to be logged.
- Internal activity that happens after `debug(false)` completes is no longer logged through the debug path.
- If activity races with a debug-state transition, callers may observe either the old or new logging behavior depending on ordering; no partial state is exposed.

## Interactions

- **setup / configuration** — many SDKs accept an initial `debug` config that establishes the starting logging state.
- **logger subsystem** — `debug(...)` directly controls whether the SDK's internal logger prints verbose diagnostics.
- **browser persistence/config** — browser ties runtime debug toggling to `set_config(...)` and `ph_debug` local storage.
- **Flutter wrapper** — Flutter delegates both setup-time and runtime debug control to the underlying native/browser SDK instead of implementing a separate Dart logging backend.

## Requirements

### Requirement: Canonical debug behavior

The SDK SHALL implement the canonical `debug` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Debug can be enabled and disabled at runtime
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** debug is set to true
- **THEN** SDK debug logging should be enabled
- **WHEN** debug is set to false
- **THEN** SDK debug logging should be disabled

#### Scenario: Debug does not emit analytics or network traffic
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** debug is set to true
- **THEN** no event should be enqueued
- **AND** no network request should be sent

#### Scenario: Debug defaults to enabled when called without an argument
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** debug is called without an enabled argument
- **THEN** SDK debug logging should be enabled
