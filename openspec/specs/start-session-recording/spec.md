# Start Session Recording Specification

## Purpose

`start-session-recording` manually starts or resumes **session replay / session recording capture** for the current client session.

It exists for SDKs that support session replay but do not want replay to start only from automatic project settings or remote-config-triggered activation. Callers use it to force replay capture when the current platform/config/session is eligible.

## Applicability

`client` — this is a client-side session replay control API.

## Public signatures

### Canonical client signature

```ts
startSessionRecording(control?: unknown): void | Promise<void>
```

### Surface variants

- **browser:** `startSessionRecording(override?: true | { sampling?: boolean; linked_flag?: boolean; url_trigger?: true; event_trigger?: true })`
- **flutter:** `startSessionRecording({ resumeCurrent = true }): Future<void>`
- **react-native:** `startSessionRecording(resumeCurrent = true): Promise<void>`
- **iOS:**
  - `startSessionRecording()`
  - `startSessionRecording(resumeCurrent: Bool)`
- **Android:** `startSessionReplay(resumeCurrent: Boolean = true)`
- **Unity:** `StartSessionReplay()`

`startSessionReplay(...)` / `StartSessionReplay()` are platform-specific aliases for the same underlying concept.

The optional control argument is **not uniform across SDKs**:
- browser uses it to override replay gating controls for the next start attempt
- React Native / iOS / Android use it to choose whether to resume the current session or rotate to a new one

## Behavior

1. **Guard / no-op if unavailable.** If the SDK is disabled, the replay integration is unavailable, or the platform does not support manual replay control, do nothing.
2. **Check whether replay is already active.** If replay is already running for the current session, the call is usually a no-op.
3. **Ensure replay infrastructure exists.**
   - Some SDKs lazily initialize/install their replay integration when this API is called.
   - Others require replay to have been configured at setup time and simply no-op/log if it is missing.
4. **Resolve the start mode.**
   - In React Native / iOS / Android, if `resumeCurrent` is `true` (the default where exposed), continue or resume recording for the current session.
   - In React Native / iOS / Android, if `resumeCurrent` is `false`, start a fresh replay session when the SDK supports that option by rotating/creating a new session id first.
   - In browser, optional override controls can mark sampling, linked-flag, URL-trigger, or event-trigger gates as satisfied for the next start attempt.
5. **Re-check replay eligibility.** Starting recording does not usually override server/project controls. Audited SDKs may still refuse to start if replay is disabled by remote config, linked-flag/session gating, or sampling rules, except where the browser override controls explicitly bypass specific local start gates.
6. **Start replay capture.** When all guards pass, the replay subsystem starts capturing screenshots/wireframes and related replay telemetry for the chosen session.
7. **Do not emit a normal analytics event directly.** This API controls replay capture state; any resulting replay snapshots or `$snapshot`-style traffic comes from the replay subsystem itself.

## State & lifecycle

### State read

- SDK enabled / initialization state
- opt-out state where enforced by the SDK
- replay integration installation/initialization state
- current replay-active state
- current session id / session manager state
- remote-config / linked-flag / sampling eligibility for replay
- browser override-control state where supported

### State written

- replay-active state
- replay integration runtime state
- optionally, current session id if the SDK starts a new session when `resumeCurrent = false`

### Lifecycle behavior

- This API can be used to manually resume replay after startup when replay is configured but not yet active.
- In SDKs with `resumeCurrent = false`, callers can force replay to begin on a fresh session instead of the existing one.
- In browser, callers can request that specific local replay-start gates be overridden for the next start attempt.
- Stopping replay later is handled by the corresponding stop API, SDK shutdown, opt-out, or replay subsystem teardown.

## Error handling

- This API should not throw in normal operation.
- Unsupported or unavailable replay integrations no-op or log.
- If replay is disabled by config/remote config/sampling/flag gating, the call logs or silently returns without starting capture.
- Promise-returning variants resolve after the start attempt completes; failures are typically logged rather than surfaced as rejected application-level errors.

## Concurrency & ordering guarantees

- Replay start/stop operations are serialized by the SDK's replay integration / session manager.
- If replay is already active, repeated start calls are usually idempotent no-ops.
- When `resumeCurrent = false` rotates the session first, subsequent replay data belongs to the newly-created session once the call completes.

## Interactions

- **`stop-session-recording` / `stopSessionReplay`** — the inverse control path that stops manual replay capture.
- **session manager** — some SDKs rotate or create a new session before starting replay.
- **remote config / linked flags / sampling** — these controls can still veto replay startup.
- **opt-out / shutdown** — these lifecycle events typically stop replay even if it was started manually.

## Requirements

### Requirement: Canonical start-session-recording behavior

The SDK SHALL implement the canonical `start-session-recording` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Start session recording activates replay capture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** session recording is inactive
- **WHEN** start session recording is called
- **THEN** session recording should be active
- **AND** is session replay active should return true
- **AND** replay snapshots should include the current session id

#### Scenario: Start session recording is idempotent
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** session recording is active
- **WHEN** start session recording is called
- **THEN** session recording should remain active
- **AND** duplicate replay recorders should not be installed

#### Scenario: Start session recording respects opt-out state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** analytics capture is opted out
- **WHEN** start session recording is called
- **THEN** session recording should remain inactive
