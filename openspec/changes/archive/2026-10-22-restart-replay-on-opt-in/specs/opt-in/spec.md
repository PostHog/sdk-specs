## Narrative alignment

When syncing this delta, change `optOut` step 5 to say that client SDKs stopping session replay also record whether the app wanted it, and change `optIn` step 4 to say that restarting replay starts a new session first. Under Interactions, replace the "some SDKs stop or restart them when opt state changes" note on session replay with a pointer to the requirements below, and note that opt-in restarts replay the app wanted even when a gate held it off at opt-out, and that the SDKs still differ on whether opt-in rotates the session when a linked flag or unloaded remote config then keeps replay from starting: posthog-ios and posthog-react-native rotate whenever replay was wanted, posthog-android only when replay starts. That case is not specified here. Leave the existing opt-in scenarios and unrelated sections unchanged.

## ADDED Requirements

### Requirement: Opt-in restarts session replay in a new session

A client SDK that stops session replay while opted out SHALL start a new session before replay restarts on opt-in, so that no frame recorded after consent is attributed to the session that was active while the user was opted out. The requirement is on the observable outcome: after opt-in restarts replay, the current session id SHALL differ from the one in use at opt-out. Where a wrapper owns the session id rather than the native SDK, the wrapper SHALL perform the rotation.

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

### Requirement: Opt-in restarts the session replay the app wanted at opt-out

The SDK SHALL decide at opt-out whether opt-in restarts session replay, from whether the app wanted replay then, not from whether it was recording. The app wants replay when session replay is enabled in its configuration or it called `startSessionRecording()`, and it has not called `stopSessionRecording()` since. When the app wanted replay, opt-in SHALL restart it in a new session even if sampling, a linked flag, or an event trigger held it off at opt-out; those gates SHALL be evaluated again for the new session. The SDK SHALL NOT restart a recording the app stopped before opting out: consent does not undo an explicit `stopSessionRecording()`. A start or stop call made while opted out SHALL NOT change that decision, because replay is stopped or uninstalled then. `reset()` SHALL clear it back to the default, so an application that launches opted out still gets replay on its first opt-in.

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
