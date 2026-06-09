# Is Session Replay Active Specification

## Purpose

`is-session-replay-active` reports whether the SDK's **session replay / session recording subsystem is currently active** for the running client instance.

It is a read-only status API. It does **not** start or stop replay, emit an event, or perform network I/O by itself.

## Applicability

`client` — this is a client-side runtime-status getter for session replay support.

## Public signatures

### Canonical client signature

```ts
isSessionReplayActive(): boolean | Promise<boolean>
```

### Surface variants

- **browser:** `sessionRecordingStarted(): boolean`
- **react-native:** `isSessionReplayActive(): Promise<boolean>`
- **iOS:** `isSessionReplayActive() -> Bool`
- **Android:** `isSessionReplayActive(): Boolean`
- **Flutter:** `isSessionReplayActive(): Future<bool>`
- **Unity:** `IsSessionReplayActive: bool` static property

`is-session-replay-active` is used here because that naming is the majority cross-SDK shape, even though the browser surface is `sessionRecordingStarted()`.

## Behavior

1. **Read current local replay state only.** The getter answers from already-available runtime state; it does not contact PostHog.
2. **Return whether replay is actively running now.**
   - Browser returns whether its session-recording integration has started.
   - Android returns whether the replay handler is active and the session itself is active.
   - iOS returns whether replay integration is active, a non-empty current session id exists, and replay is allowed by remote-config flag state.
   - Unity returns whether its replay integration exists and is currently active.
   - React Native delegates to the native replay module and returns its current enabled/active status.
   - Flutter delegates to the underlying native/browser SDK and exposes a unified boolean result.
3. **Fail closed when replay is unavailable.** If the SDK is disabled, uninitialized, unsupported on the current platform, or replay integration is absent, audited implementations return `false`.
4. **Reflect prior replay lifecycle calls and config changes.** Reads change after successful `startSessionRecording(...)` / `stopSessionRecording()` calls, initialization, shutdown, session rotation, or replay gating changes.
5. **Do not mutate replay state.** This getter is observational only.

## State & lifecycle

### State read

- SDK enabled / initialized state
- replay integration existence and internal active flag
- current session state / session id
- replay-related remote config or platform support state where applicable

### State written

None.

### Lifecycle behavior

- Before replay initialization, or when replay is unsupported, the getter returns `false`.
- After replay starts successfully, the getter returns `true` until replay stops or becomes ineligible.
- Shutdown/close paths return the system to `false`.
- Wrapper SDKs may delegate the lifecycle entirely. Flutter reads the underlying platform/browser replay status rather than computing an independent Dart-owned truth value.

## Error handling

- This API should not throw in normal operation.
- Audited wrappers and native SDKs generally return `false` when unavailable or when the status check fails.
- Promise-returning variants resolve to a boolean status rather than surfacing rich status objects.

## Concurrency & ordering guarantees

- Reads are side-effect-free and observe the SDK's current replay state.
- A read performed after replay start/stop completes reflects the resulting state.
- If reads race with replay lifecycle transitions, callers may observe either the pre-transition or post-transition value depending on ordering; no partial state is exposed.

## Interactions

- **`start-session-recording` / `stop-session-recording`** — these APIs change the state that this getter reports.
- **session manager** — some SDKs require an active session / session id for replay to count as active.
- **remote config / feature flags** — replay eligibility or active status may depend on remote-config gating.
- **shutdown / close** — teardown paths typically make this getter return `false`.
- **wrapper replay helpers** — Flutter and React Native expose a unified replay-status getter over native/browser replay implementations.

## Requirements

### Requirement: Canonical is-session-replay-active behavior

The SDK SHALL implement the canonical `is-session-replay-active` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Replay active reports false before recording starts
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** is session replay active is called
- **THEN** the returned replay active value should be false

#### Scenario: Replay active reports true after manual start
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **WHEN** start session recording is called
- **AND** is session replay active is called
- **THEN** the returned replay active value should be true

#### Scenario: Replay active reports false after manual stop
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session recording is active
- **WHEN** stop session recording is called
- **AND** is session replay active is called
- **THEN** the returned replay active value should be false
