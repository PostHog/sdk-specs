# Opt In Specification

## Purpose

`opt-in` and `opt-out` control whether the client SDK is allowed to capture and persist analytics data for the current installation/session.

They are a tightly-coupled pair:

- **`opt-out`** disables future capture
- **`opt-in`** re-enables capture after an opt-out

These APIs are primarily **local consent/state mutations**. In most SDKs they do not emit analytics events themselves, though the browser SDK has additional consent-specific behavior.

## Applicability

`client` — opt-in/opt-out are client-side consent/capture-gating APIs. Server SDKs are stateless per call and generally do not expose a comparable persistent per-user consent toggle.

## Public signatures

### Canonical client signatures

```ts
optIn(): void | Promise<void>
optOut(): void | Promise<void>
```

### Surface variants

- **posthog-js core / react-native:** `optIn()` / `optOut()`
- **iOS:** `optIn()` / `optOut()`
- **Android:** `optIn()` / `optOut()`
- **Flutter:** `optIn()` / `optOut()` (since 5.51.0) — `enable()` / `disable()` are deprecated since 5.51.0; their removal is merged for Flutter 6.0 (unreleased)
- **Unity:** `OptIn()` / `OptOut()` static methods
- **browser:** `opt_in_capturing(options?)` / `opt_out_capturing()`

Browser-specific opt-in accepts extra options such as a custom capture event name/properties for the consent action.

## Behavior

### `optOut`

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op.
2. **Persist opted-out state.** Store a local flag indicating capture is disabled.
3. **Block future capture.** Subsequent `capture(...)`, `identify(...)`, `group(...)`, and related APIs short-circuit while opted out.
4. **Keep the decision across restarts.** The opted-out state is persisted locally in audited SDKs so it survives app restarts.
5. **Apply SDK-specific cleanup if needed.** Some SDKs also clear in-flight data or stop auxiliary systems such as session replay. Mobile client SDKs that stop session replay also record there and then whether the app wanted it, because that decides what opt-in restarts.

### `optIn`

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op.
2. **Persist opted-in state.** Clear the local opt-out flag so capture becomes allowed again.
3. **Re-enable future capture.** Subsequent analytics APIs are processed normally.
4. **Re-enable SDK subsystems if needed.** Some SDKs restart paused integrations or queues. Where a mobile client SDK restarts session replay, a new session starts first.
5. **Keep the decision across restarts.** The opted-in state is persisted locally in audited SDKs.

## State & lifecycle

### State read

- current opt-out / consent state
- SDK enabled / initialization state

### State written

- persistent opt-out flag / consent status storage

### Lifecycle behavior

- Opt-out persists until the caller explicitly opts back in, or until `reset()` in SDKs where reset clears the opt-out state.
- Opt-in restores normal capture for future calls only; already-dropped events are not recreated.
- Browser consent-specific APIs may additionally reset or reinitialize persistence/session state when switching between consent modes.

## Error handling

- These APIs should not throw in normal operation.
- Repeated calls in the same state are typically harmless no-ops.
- Disabled / unavailable SDKs no-op.
- Storage failures are generally swallowed/logged rather than surfaced to application code.

## Concurrency & ordering guarantees

- Consent-state reads/writes are serialized by the SDK's normal storage / locking model.
- A `capture(...)` call issued after `optOut()` completes observes the opted-out state and is dropped.
- A `capture(...)` call issued after `optIn()` completes is allowed again.
- If a capture races with an opt transition, callers may observe either the pre-transition or post-transition behavior depending on ordering; no partial state is exposed.

## Interactions

- **`capture` / `identify` / `group` / `alias`** — all are gated by the opt-out state in audited client SDKs.
- **`reset`** — in several audited SDKs, reset clears the persisted opt-out state, so opt-out should not be treated as stronger-than-reset privacy state.
- **Session replay / integrations** — some SDKs stop or restart them when opt state changes. Where a mobile
  client SDK restarts replay on opt-in, the requirements below govern the new session and the restart decision. Opt-in restarts
  replay the app wanted at opt-out even when sampling, a linked flag, or an event trigger held it off then; those
  gates are evaluated again in the new session.
- **Browser consent APIs** — browser uses richer consent semantics than the mobile/core SDKs and maps opt-in/out to persistence and cookieless-mode behavior. The replay restart requirements below do not apply to it.

## Requirements

### Requirement: Canonical opt-in behavior

The SDK SHALL implement the canonical `opt-in` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Opt out prevents event capture and persists consent state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** opt out is called
- **THEN** is opt out should return true
- **AND** persistent storage should contain opt-out state "true"
- **WHEN** capture is called with event "Blocked"
- **THEN** no event should be enqueued

#### Scenario: Opt in re-enables capture and persists consent state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted out
- **WHEN** opt in is called
- **THEN** is opt out should return false
- **AND** persistent storage should contain opt-out state "false"
- **WHEN** capture is called with event "Allowed"
- **THEN** one event named "Allowed" should be enqueued

#### Scenario: Opt out can clear local persistence when configured
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** persistent storage contains identity and super properties
- **WHEN** opt out is called with local data clearing enabled
- **THEN** persisted identity and super properties should be cleared
- **AND** analytics capture should be opted out

### Requirement: Opt-in restarts session replay in a new session

A mobile client SDK (iOS, Android, React Native, or Flutter on a native platform) that stops session replay while opted out SHALL start a new session before replay restarts on opt-in, so that no frame recorded after consent is attributed to the session that was active while the user was opted out. The requirement is on the observable outcome: after opt-in restarts replay, the current session id SHALL differ from the one in use at opt-out. Where a wrapper owns the session id rather than the native SDK, the wrapper SHALL perform the rotation. When the app wanted replay at opt-out, opt-in SHALL start the new session even if a linked flag or remote config that has not loaded keeps replay from starting, so that a later start does not resume the session that was active while the user was opted out. This requirement does not apply to browser `opt_in_capturing` / `opt_out_capturing`, which have their own consent semantics, or to Flutter on web, which leaves replay to posthog-js.

#### Scenario: Opt in restarts replay in a new session
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** the current session id is "session-123"
- **AND** session recording is active
- **WHEN** opt out is called
- **AND** opt in is called
- **THEN** session recording should be active
- **WHEN** get session id is called
- **THEN** the returned session id should not be "session-123"

#### Scenario: Opt in starts a new session while a linked flag holds replay off
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is enabled
- **AND** the remote config links recording to flag "replay-flag" variant "test"
- **AND** feature flag "replay-flag" resolves to variant "control" for the user
- **AND** the current session id is "session-123"
- **WHEN** opt out is called
- **AND** opt in is called
- **THEN** session recording should not be active
- **WHEN** get session id is called
- **THEN** the returned session id should not be "session-123"

### Requirement: Opt-in restarts the session replay the app wanted at opt-out

A mobile client SDK (iOS, Android, React Native, or Flutter on a native platform) that stops session replay while opted out SHALL decide at opt-out whether opt-in restarts session replay, from whether the app wanted replay then, not from whether it was recording. The app wants replay when session replay is enabled in its configuration or it called `startSessionRecording()`, and it has not called `stopSessionRecording()` since. When the app wanted replay, opt-in SHALL restart it in a new session even if sampling, a linked flag, or an event trigger held it off at opt-out; those gates SHALL be evaluated again for the new session. The SDK SHALL NOT restart a recording the app stopped before opting out: consent does not undo an explicit `stopSessionRecording()`. A start or stop call made while opted out SHALL NOT change that decision, because replay is stopped or uninstalled then. At launch the decision SHALL start from the configuration, so an application that launches opted out with session replay enabled records on its first opt-in. This requirement does not apply to the browser SDK or to Flutter on web: a browser `stopSessionRecording()` stays in effect through opt-out and opt-in, including when it is called while opted out.

#### Scenario: Opt in keeps a recording the app stopped stopped
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** session recording is active
- **WHEN** stop session recording is called
- **AND** opt out is called
- **AND** opt in is called
- **THEN** session recording should remain inactive
- **AND** is session replay active should return false

#### Scenario: Opt in restarts a recording the app started manually
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is not configured locally
- **AND** the current session id is "session-123"
- **WHEN** start session recording is called
- **AND** opt out is called
- **AND** opt in is called
- **THEN** session recording should be active
- **WHEN** get session id is called
- **THEN** the returned session id should not be "session-123"

#### Scenario: Opt in restarts replay that an event trigger held off at opt out
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** the current session id is "session-123"
- **AND** session recording is inactive
- **WHEN** opt out is called
- **AND** opt in is called
- **THEN** session recording should not be active
- **WHEN** the trigger event is captured
- **THEN** session recording should be active
- **WHEN** get session id is called
- **THEN** the returned session id should not be "session-123"

#### Scenario: Stopping a recording while opted out does not block the restart
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** session recording is active
- **WHEN** opt out is called
- **AND** stop session recording is called
- **AND** opt in is called
- **THEN** session recording should be active

#### Scenario: An application that launched opted out records on its first opt in
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** analytics capture is opted out
- **WHEN** opt in is called
- **THEN** session recording should be active
