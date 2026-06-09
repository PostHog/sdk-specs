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
- **Unity:** `OptIn()` / `OptOut()` static methods
- **browser:** `opt_in_capturing(options?)` / `opt_out_capturing()`

Browser-specific opt-in accepts extra options such as a custom capture event name/properties for the consent action.

## Behavior

### `optOut`

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op.
2. **Persist opted-out state.** Store a local flag indicating capture is disabled.
3. **Block future capture.** Subsequent `capture(...)`, `identify(...)`, `group(...)`, and related APIs short-circuit while opted out.
4. **Keep the decision across restarts.** The opted-out state is persisted locally in audited SDKs so it survives app restarts.
5. **Apply SDK-specific cleanup if needed.** Some SDKs also clear in-flight data or stop auxiliary systems such as session replay.

### `optIn`

1. **Guard / no-op if unavailable.** Disabled or uninitialized SDKs no-op.
2. **Persist opted-in state.** Clear the local opt-out flag so capture becomes allowed again.
3. **Re-enable future capture.** Subsequent analytics APIs are processed normally.
4. **Re-enable SDK subsystems if needed.** Some SDKs restart paused integrations or queues.
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
- **Session replay / integrations** — some SDKs stop or restart them when opt state changes.
- **Browser consent APIs** — browser uses richer consent semantics than the mobile/core SDKs and maps opt-in/out to persistence and cookieless-mode behavior.

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
