# Get Session ID Specification

## Purpose

`get-session-id` returns the SDK's **current analytics session identifier**.

This is the same session identifier that session-aware client SDKs attach to captured events as `$session_id` and use for other session-scoped features such as replay/window grouping.

This API is a **local state read**. It does not send analytics events or perform network I/O.

## Applicability

`client` — this is a client-side session-state access API. Server SDKs are stateless per call and generally do not expose an ambient session-id getter.

## Public signatures

### Canonical client signature

```ts
getSessionId(): string | null
```

### Surface variants

- **posthog-js core / react-native:** `getSessionId(): string`
- **browser:** `get_session_id(): string`
- **flutter:** `getSessionId(): Future<String?>`
- **iOS:** `getSessionId() -> String?`
- **Android:** `getSessionId(): UUID?`

Some SDKs always expose the session id as a string, while Android exposes a nullable `UUID` object.

## Behavior

1. **Guard if unavailable.** Disabled or not-yet-usable SDK instances return an empty / null result instead of forcing network work.
2. **Read the current session state from the session manager or persisted session store.**
3. **Return the current session id if one is already active.**
4. **If the getter is coupled to session maintenance, lazily create or rotate the session first.**
   - js-core-based implementations validate the stored session against inactivity and maximum-length thresholds.
   - If the stored session is missing or expired, they generate a new session id and persist updated timestamps before returning.
5. **If the getter is explicitly read-only, do not start a new session.**
   - iOS calls its session manager in `readOnly` mode.
   - Android returns only the currently active session id from `PostHogSessionManager`.
6. **Do not emit analytics events or contact the network.** The result comes entirely from local in-memory or persisted state.

## State & lifecycle

### State read

- current session id
- session last-activity timestamp
- session start timestamp / maximum-age tracking
- app foreground/background state in SDKs whose session manager distinguishes them
- SDK enabled / initialization state

### State written

- usually none for read-only surfaces
- in js-core-style surfaces, the getter may update:
  - persisted/current session id
  - session start timestamp
  - session last-activity timestamp

### Lifecycle behavior

- Before a session exists, the getter may either:
  - lazily create and return a new session id, or
  - return `null` / empty because no session is currently active.
- During an active session, repeated reads return the same id until the session manager rotates or clears it.
- After expiry or explicit session reset, the next returned value may be a new session id or no active session, depending on the SDK's session-manager policy.
- After app restart, the returned value depends on the SDK's session persistence policy and whether the prior session is still considered active.

## Error handling

- This API should not throw in normal operation.
- Disabled or unavailable SDK instances return an empty string (`posthog-js` family) or `nil`/`null` (`Flutter`, `iOS`, `Android`) instead of failing.
- Missing session state is handled by returning no active session or lazily creating one, depending on the SDK.

## Concurrency & ordering guarantees

- Session-state access is serialized by the SDK's normal event-loop or locking model.
- Callers observe a session id consistent with the session manager's current local state at the moment of the call.
- If session rotation is racing on another thread or event loop turn, callers observe either the pre-rotation or post-rotation id; no partial session state is exposed.

## Interactions

- **Session manager** — this getter is the public read surface over the SDK's internal session lifecycle state.
- **`capture` / `screen` / replay pipelines** — these features typically attach or consume the same session id returned here.
- **Session-start / session-reset APIs** — where exposed, they affect the value this getter returns.
- **`reset`** — may indirectly clear or rotate session-related state depending on the SDK.

## Requirements

### Requirement: Canonical get-session-id behavior

The SDK SHALL implement the canonical `get-session-id` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Getting the session id creates or returns an active session
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** get session id is called
- **THEN** the returned session id should not be empty
- **AND** capture should attach the same value as property "$session_id"

#### Scenario: Session id remains stable within the inactivity timeout
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** get session id returned "session-123"
- **WHEN** the SDK clock advances by "10 minutes"
- **AND** get session id is called
- **THEN** the returned session id should be "session-123"

#### Scenario: Session id rotates after inactivity timeout
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** get session id returned "session-123"
- **WHEN** the SDK clock advances past the session inactivity timeout
- **AND** get session id is called
- **THEN** the returned session id should not be "session-123"
