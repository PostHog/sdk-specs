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
3. **Block future capture.** Subsequent `capture(...)`, `group(...)`, and related APIs short-circuit while opted out. `identify(...)` does not short-circuit: it still updates local identity state and person properties for flags, and reloads feature flags when the distinct id changes. Only its `$identify` / `$set` event is not captured (see `identify`).
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

- **`capture` / `group` / `alias`** — all are gated by the opt-out state in audited client SDKs.
- **`identify`** — opt-out blocks only the `$identify` / `$set` event. `identify` still updates local identity state (distinct id, anonymous id, identified flag) and person properties for flags, and reloads feature flags when the distinct id changes. Feature flag loading is not gated by opt-out. `bootstrap` follows the same rule: opt-out suppresses event emission, not the local identity state.
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

### Requirement: Consent event is captured once per opt-in transition

An SDK that captures a consent event when the caller opts in — `$opt_in` in the browser — SHALL
capture it only when the call changes the stored consent state. When the caller is already opted
in, the SDK SHALL capture no consent event.

Consent managers commonly call the opt-in API from a consent-change callback that fires on every
page load once consent is stored, so capturing on every call sends one consent event per page view
that records nothing the previous one did not.

A caller-supplied consent event name is the same event under another name and SHALL be suppressed
on the same terms.

Consent already stored and read back by a later page load or SDK instance counts as already opted
in. Opting out and opting back in, and a `reset()` followed by an opt-in, are transitions and SHALL
capture the consent event again.

Suppression covers the consent event only. Everything else the opt-in path does — persisting the
consent state, resuming capture, draining queued work, restarting subsystems such as session replay
and surveys, and any initial pageview the SDK sends on opt-in — SHALL still run on a repeat call.

#### Scenario: Opting in twice captures one consent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **WHEN** opt in is called
- **THEN** one consent event should be enqueued
- **WHEN** opt in is called again
- **THEN** no further consent event should be enqueued

#### Scenario: A custom consent event name is suppressed on the same terms
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **AND** analytics capture is opted in
- **WHEN** opt in is called with a custom consent event name
- **THEN** no event with that name should be enqueued

#### Scenario: Stored consent read on a later load captures no consent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** the mock PostHog server is reset
- **AND** persistent storage contains opt-out state "false"
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **WHEN** opt in is called
- **THEN** no consent event should be enqueued

#### Scenario: Opting out and back in captures the consent event again
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **AND** analytics capture is opted in
- **WHEN** opt out is called
- **AND** opt in is called
- **THEN** one consent event should be enqueued

#### Scenario: A repeat opt in still resumes capture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted in
- **WHEN** opt in is called again
- **THEN** is opt out should return false
- **AND** persistent storage should contain opt-out state "false"
- **WHEN** capture is called with event "Allowed"
- **THEN** one event named "Allowed" should be enqueued
