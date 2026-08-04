# Session Replay Ingestion Controls Delta: Idle-Rotation Replay Hold

## ADDED Requirements

### Requirement: Idle-rotation replay hold until interaction

When a session id rotates because of an inactivity/idle timeout — not because the SDK is starting a fresh session — while recording is not yet confirmed active for that session, the SDK SHALL withhold emitting the rotated session's buffered replay data until the earliest of: the first genuine user interaction is captured, or an event/URL trigger independently activates recording. Buffered data held under this rule that is never released (for example because the SDK stops, the user opts out, or the buffer is discarded on a further rotation) SHALL NOT be emitted. A fresh (non-rotation) session start is NOT subject to this hold.

This requirement applies to SDKs whose sessions rotate on an inactivity timeout while idle (currently posthog-js / web). SDKs without an idle-rotation concept, or whose sessions never rotate while idle, are exempt.

#### Scenario: Idle-timeout rotation withholds recording until interaction
- **GIVEN** session replay is enabled and active
- **AND** the current session is idle with no confirmed user interaction
- **WHEN** the session id rotates because of an inactivity timeout
- **THEN** the rotated session's replay data should be withheld
- **WHEN** the client captures a genuine user interaction event
- **THEN** the withheld replay data should be released and recording should be active

#### Scenario: A fresh session start is not held
- **GIVEN** session replay is enabled
- **AND** the SDK starts a brand-new session that is not the result of an idle-timeout rotation
- **WHEN** the SDK resolves whether to record the session
- **THEN** session recording should be active without waiting for a user interaction
