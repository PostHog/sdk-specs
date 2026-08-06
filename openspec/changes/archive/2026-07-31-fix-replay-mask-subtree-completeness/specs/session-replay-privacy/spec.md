## MODIFIED Requirements

### Requirement: Canonical session-replay-privacy behavior

The SDK SHALL implement the canonical `session-replay-privacy` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Replay privacy masks text in masked elements
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an element marked as masked containing text "secret"
- **THEN** the replay snapshot should not contain text "secret"
- **AND** the replay snapshot should contain masked text only

#### Scenario: Replay privacy masks every matching element in a subtree, not only the first match
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an explicitly masked subtree containing multiple children, including at least one child that does not itself match any masking rule
- **THEN** the replay snapshot should not reveal any content from that subtree
- **AND** every matching descendant within the subtree should be masked, not only the first one discovered during tree traversal

#### Scenario: Replay privacy excludes no-capture elements
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an element marked no-capture
- **THEN** the replay snapshot should not include that element or its descendants

#### Scenario: Replay privacy redacts sensitive inputs by default
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for a password input containing "secret-password"
- **THEN** the replay snapshot should not contain text "secret-password"

#### Scenario: Privacy rules apply before replay data is queued
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot containing masked text is processed
- **THEN** queued replay data should already be redacted
