# Session Replay Ingestion Controls Delta: Idle-Rotation Replay Hold

## ADDED Requirements

### Requirement: Interaction hold for unconfirmed-activity recording epochs

When a new recording epoch begins — whether from a session id rotating because of an inactivity/idle timeout, or from a fresh (non-rotation) session start — without confirmed user activity for that epoch, the SDK SHALL withhold emitting the epoch's buffered replay data until the earliest of: the first genuine user interaction is captured, an event/URL trigger independently activates recording, or an explicit recording override (for example a `startSessionRecording(...)`-style call, which is explicit intent to record) is invoked. Buffered data held under this rule that is never released SHALL NOT be emitted. A clean page/app unload SHALL release and ship a held fresh-start epoch's buffered data, preserving pre-hold behavior for passive visits (e.g. reading, watching); a held rotation-born epoch's data SHALL NOT be released on unload and is discarded instead — an idle tab that rotates and is never interacted with again must not ship a recording.

This requirement applies to SDKs whose sessions can start or rotate without a confirmed-interaction signal (currently posthog-js / web). SDKs without this concept, or whose sessions never start/rotate this way, are exempt.

#### Scenario: Idle-timeout rotation withholds recording until interaction
- **GIVEN** session replay is enabled and active
- **AND** the current session is idle with no confirmed user interaction
- **WHEN** the session id rotates because of an inactivity timeout
- **THEN** the rotated session's replay data should be withheld
- **WHEN** the client captures a genuine user interaction event
- **THEN** the withheld replay data should be released and recording should be active

#### Scenario: A fresh session start without confirmed activity is held until interaction
- **GIVEN** session replay is enabled
- **AND** the SDK starts a brand-new session that is not the result of an idle-timeout rotation
- **AND** no user activity has been confirmed for the new session yet
- **WHEN** the SDK resolves whether to record the session
- **THEN** the session's replay data should be withheld
- **WHEN** the client captures a genuine user interaction event
- **THEN** the withheld replay data should be released and recording should be active

#### Scenario: A clean unload ships a held fresh-start epoch but not a held rotation-born epoch
- **GIVEN** session replay is enabled
- **AND** a fresh session start is held with no confirmed user activity
- **WHEN** the page or app unloads cleanly
- **THEN** the held fresh-start epoch's buffered replay data should be released and shipped
- **GIVEN** a rotated session is held with no confirmed user activity
- **WHEN** the page or app unloads cleanly
- **THEN** the held rotation-born epoch's buffered replay data should be discarded, not shipped
