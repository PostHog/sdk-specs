## Narrative alignment

When syncing this delta, change `optOut` step 5 to say that client SDKs stopping session replay also record whether the app wanted it, and change `optIn` step 4 to say that restarting replay starts a new session first. Under Interactions, replace the "some SDKs stop or restart them when opt state changes" note on session replay with a pointer to the requirements below, and note that the SDKs still diverge when replay is enabled but held off at opt-out by sampling, a linked flag, an event trigger, or remote config that has not loaded: posthog-ios and posthog-react-native leave it stopped on opt-in, posthog-android restarts it and lets the normal gates decide. That case is not specified here. Leave the existing opt-in scenarios and unrelated sections unchanged.

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

### Requirement: Opt-in does not restart a recording the app stopped

The SDK SHALL decide at opt-out whether opt-in may restart session replay, and SHALL NOT restart a recording the app had stopped before opting out. Consent does not undo an explicit `stopSessionRecording()`. A start or stop call made while opted out SHALL NOT change that decision, because replay is stopped or uninstalled then. `reset()` SHALL clear it back to the default, so an application that launches opted out still gets replay on its first opt-in.

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
