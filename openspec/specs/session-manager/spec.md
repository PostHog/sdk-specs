# Session Manager Specification

## Purpose

`session-manager` is the internal component that determines the **current analytics session id** and decides when that session should start, continue, rotate, or end.

It is responsible for attaching a stable `$session_id` to events for a bounded period of user activity, so related events can be analyzed as one session rather than as isolated events.

## Applicability

`client` — the audited implementations are client-side session managers that track ambient session state for a running app/browser instance.

## Public signature(s)

No single canonical public API.

Typical internal operations look like:

```ts
getSessionId(now?, readOnly?): string | null
startSession(): void
endSession(): void
resetSession(): void
setSessionId(id): void
touchSession(): void
```

Some SDKs expose thin public wrappers over these operations.

## Behavior

1. **Return an active session id when available.** If a session is already active and valid, reuse its id.
2. **Create a session when needed.** If no session exists and the SDK considers the app/session active, generate a new session id.
3. **Track activity timestamps.** Record the last-activity time whenever event activity or lifecycle activity touches the session.
4. **Rotate after inactivity timeout.** If the idle period exceeds the SDK's session timeout, create a new session (or clear the session when backgrounded, depending on implementation).
5. **Rotate after maximum session length.** If a session lives too long even with activity, force a new session id.
6. **Allow explicit session boundaries.** `startSession`, `endSession`, and `resetSession` / `startNewSession` let higher layers force a new or cleared session.
7. **Persist session state when the SDK chooses to survive restarts.** Some SDKs store session id and timestamps in persistent storage; others keep the session only in memory.
8. **Attach the current session id to events.** Higher layers read the manager when building event properties and stamp `$session_id` (and sometimes `$window_id`).
9. **Notify dependents on session changes.** Some implementations emit callbacks or are polled by replay/feature modules when the session id changes.
10. **Allow wrapper SDKs to delegate session ownership to an underlying platform manager.** Flutter's Dart layer does not implement its own session-id algorithm; it delegates `getSessionId()` and replay start/stop boundaries to the native/browser SDKs and mirrors replay-active state into a wrapper-side notifier used by the Flutter replay widget.

## State & lifecycle

### State read

- current session id
- session start timestamp
- last activity timestamp
- foreground/background state where applicable
- persisted session state (in SDKs that store it)

### State written

- session id
- session start timestamp
- last activity timestamp
- optional persisted session state
- session-changed notifications in SDKs that expose them
- wrapper-side replay/session-active notifiers in SDKs that proxy another manager (for example Flutter's `sessionRecordingActive` value)

### Lifecycle behavior

- **Fresh start:** session id is created lazily on first relevant access or explicit start.
- **Foreground/background transitions:** some SDKs update activity timestamps, rotate, or clear the session based on app state.
- **Reset/logout:** many SDKs start a new session as part of `reset()`.
- **Long-lived sessions:** forced rotation occurs when the session exceeds the configured maximum length.
- **Wrapper-driven replay lifecycles:** Flutter's replay widget starts/stops local snapshot capture based on a wrapper-side `sessionRecordingActive` notifier, while session-id lifecycle itself remains owned by the underlying native/browser session managers.

## Error handling

- Session-manager operations should not throw in normal operation.
- Storage failures while persisting/restoring session state are logged and the SDK falls back to empty/default session state.
- Missing session state is handled by creating or returning no session rather than raising an error.

## Concurrency & ordering guarantees

- Session-state reads/writes are lock-protected or serialized.
- A caller sees either the old session id or the new rotated session id, never a partial state.
- Event builders that query the session manager immediately after a rotation observe the new session id.

## Interactions

- **`capture`** — reads the current session id and stamps `$session_id` on outgoing events.
- **`reset`** — often forces a session reset/start so post-reset activity falls into a new session.
- **session replay** — commonly uses the same session id and may also derive `$window_id` from it.
- **wrapper replay controls** — Flutter mirrors replay start/stop state into `PostHogInternalEvents.sessionRecordingActive`, and its replay widget listens to that notifier while sending snapshot metadata that includes the wrapper's current screen context.
- **persistent storage** — stores session ids/timestamps in SDKs that persist sessions across restarts.

## Requirements

### Requirement: Canonical session-manager behavior

The SDK SHALL implement the canonical `session-manager` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Session manager creates and reuses an active session
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** the session id is requested
- **THEN** the returned session id should not be empty
- **WHEN** the session id is requested again
- **THEN** the returned session id should be the same as the previous session id

#### Scenario: Session manager rotates after inactivity timeout
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current session id is "session-123"
- **WHEN** the SDK clock advances past the session inactivity timeout
- **AND** the session id is requested
- **THEN** the returned session id should not be "session-123"

#### Scenario: Session manager rotates after maximum session length
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current session id is "session-123"
- **WHEN** the SDK clock advances past the maximum session length
- **AND** the session id is requested
- **THEN** the returned session id should not be "session-123"

#### Scenario: Explicit session reset starts a new session
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current session id is "session-123"
- **WHEN** the session manager resets the session
- **THEN** the current session id should not be "session-123"
