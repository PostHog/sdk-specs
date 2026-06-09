# Stop Session Recording Specification

## Purpose

`stop-session-recording` manually stops **session replay / session recording capture** for the current client session.

It exists for SDKs that support manual replay control and need an explicit way to stop further replay capture before the SDK is shut down or opted out.

## Applicability

`client` — this is a client-side session replay control API.

## Public signatures

### Canonical client signature

```ts
stopSessionRecording(): void | Promise<void>
```

### Surface variants

- **browser:** `stopSessionRecording()`
- **flutter:** `stopSessionRecording(): Future<void>`
- **react-native:** `stopSessionRecording(): Promise<void>`
- **iOS:** `stopSessionRecording()`
- **Android:** `stopSessionReplay()`
- **Unity:** `StopSessionReplay()`

`stopSessionReplay()` / `StopSessionReplay()` are platform-specific aliases for the same underlying concept.

## Behavior

1. **Guard / no-op if unavailable.** If the SDK is disabled, replay is unsupported on the current platform, or no replay integration exists, do nothing.
2. **Check whether replay is active.** If replay is already inactive, the call is typically a no-op.
3. **Stop replay capture.**
   - Browser disables session recording via configuration, allowing the replay subsystem to stop itself.
   - Native/mobile SDKs usually call directly into the replay integration or platform replay handler to stop capture.
4. **Do not emit a normal analytics event directly.** This API controls replay state; it does not itself send a capture event.
5. **Leave the rest of the SDK running.** Events, feature flags, identity, and other SDK functionality continue unless separately shut down or opted out.

## State & lifecycle

### State read

- SDK enabled / initialization state
- current replay-active state
- replay integration installation/availability state

### State written

- replay-active state
- replay integration runtime state
- browser replay configuration state where stop is config-driven

### Lifecycle behavior

- After the stop call completes, the replay subsystem should stop producing new replay snapshots/telemetry for the current session.
- Later replay capture can typically be resumed only by the corresponding start API or by config/remote-config-driven replay enablement.
- This API is narrower than shutdown/opt-out: it stops replay only, not the whole analytics SDK.

## Error handling

- This API should not throw in normal operation.
- Unsupported or unavailable replay integrations no-op or log.
- Promise-returning variants resolve after the stop attempt completes; failures are typically logged rather than surfaced as rejected application-level errors.

## Concurrency & ordering guarantees

- Replay start/stop operations are serialized by the SDK's replay integration / session manager.
- Repeated stop calls are generally idempotent once replay is inactive.
- Replay data already queued before stop may still flush according to the SDK's replay pipeline, but no new replay capture should begin after the stop takes effect.

## Interactions

- **`start-session-recording` / `startSessionReplay`** — the inverse control path that manually starts or resumes replay capture.
- **opt-out / shutdown** — broader lifecycle controls that also stop replay as part of disabling the SDK or tearing it down.
- **session replay integrations** — this API directly affects only the replay subsystem, not ordinary analytics capture.

## Requirements

### Requirement: Canonical stop-session-recording behavior

The SDK SHALL implement the canonical `stop-session-recording` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Stop session recording deactivates replay capture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session recording is active
- **WHEN** stop session recording is called
- **THEN** session recording should be inactive
- **AND** is session replay active should return false

#### Scenario: Stop session recording finalizes pending replay data
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session recording is active with pending replay data
- **WHEN** stop session recording is called
- **THEN** pending replay data should be finalized before the recorder stops
- **AND** no new replay snapshots should be captured

#### Scenario: Stop session recording is safe when inactive
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session recording is inactive
- **WHEN** stop session recording is called
- **THEN** the call should not throw
- **AND** session recording should remain inactive
