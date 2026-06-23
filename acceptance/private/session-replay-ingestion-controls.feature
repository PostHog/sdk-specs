@private @canonical_behavior @acceptance @session_replay_ingestion_controls @client
Feature: Session Replay Ingestion Controls
  Acceptance tests for the canonical session replay ingestion-control behavior across PostHog SDKs.
  These controls decide automatically whether replay is active for the current session, and how the
  individual controls combine via AND (all SDKs) vs OR (SDKs with a configurable trigger match type).

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  # Replay enablement gate

  Scenario: Remote config disables replay
    Given the SDK is initialized with token "test-token" and session replay configured locally
    And the remote config reports session recording as disabled
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  Scenario: Local config disables replay even when remote is active
    Given the SDK is initialized with token "test-token" and session replay disabled in local config
    And the remote config reports session recording as active
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  Scenario: Both local and remote enable replay with no other controls
    Given the SDK is initialized with token "test-token" and session replay configured locally
    And the remote config reports session recording as active with no linked flag, sampling, or triggers
    When the SDK resolves whether to record the current session
    Then session recording should be active

  # Linked feature flag gating

  Scenario: Boolean linked flag enabled activates recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config links recording to boolean flag "replay-flag"
    And feature flag "replay-flag" is enabled for the user
    When the SDK resolves whether to record the current session
    Then session recording should be active

  Scenario: Linked flag absent or disabled prevents recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config links recording to boolean flag "replay-flag"
    And feature flag "replay-flag" is not enabled for the user
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  Scenario: Linked flag variant must match
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config links recording to flag "replay-flag" variant "test"
    And feature flag "replay-flag" resolves to variant "test" for the user
    When the SDK resolves whether to record the current session
    Then session recording should be active

  Scenario: Linked flag variant mismatch prevents recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config links recording to flag "replay-flag" variant "test"
    And feature flag "replay-flag" resolves to variant "control" for the user
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  # Sampling gating

  Scenario: Full sample rate records the session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the recording sample rate to 1.0
    When the SDK resolves whether to record the current session
    Then session recording should be active

  Scenario: Zero sample rate does not record the session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the recording sample rate to 0.0
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  Scenario: Sampling decision is stable within a session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the recording sample rate to 0.5
    And the SDK has made a sampling decision for the current session id
    When the SDK re-resolves whether to record the same session id
    Then the sampling decision should be unchanged from the first decision

  Scenario: New session id re-decides sampling
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the recording sample rate to 0.5
    And the SDK has made a sampling decision for the current session id
    When the session id rotates and the SDK resolves recording for the new session id
    Then a fresh sampling decision should be made for the new session id

  # Event-trigger gating

  Scenario: Matching event activates recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures event trigger "$pageview"
    And session recording is not active because the trigger has not fired
    When the client captures an event named "$pageview"
    Then session recording should be active

  Scenario: Non-matching events do not activate recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures event trigger "$pageview"
    When the client captures an event named "some_other_event"
    Then session recording should not be active

  Scenario: Activation persists for the rest of the session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures event trigger "$pageview"
    And an event named "$pageview" has activated recording for the current session
    When the SDK re-resolves whether to record the same session
    Then session recording should remain active

  Scenario: New session requires a fresh matching event
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures event trigger "$pageview"
    And an event named "$pageview" has activated recording for the current session
    When the session id rotates to a new session
    Then session recording should not be active until the client captures "$pageview" again

  Scenario: An event dropped by before-send does not activate the trigger
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures event trigger "$pageview"
    And a before-send hook drops events named "$pageview"
    When the client captures an event named "$pageview"
    Then session recording should not be active

  # URL-trigger gating (URL-capable SDKs only)

  @url_capable
  Scenario: Matching URL activates recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures a URL trigger matching "/checkout"
    And session recording is not active
    When the current URL changes to one matching "/checkout"
    Then session recording should be active

  @url_capable
  Scenario: Non-matching URL does not activate recording
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config configures a URL trigger matching "/checkout"
    When the current URL is one that does not match "/checkout"
    Then session recording should not be active

  # URL blocklist pause and resume (URL-capable SDKs only)

  @url_capable
  Scenario: Navigating to a blocklisted URL pauses recording
    Given the SDK is initialized with token "test-token" and session replay enabled and active
    And the remote config configures a URL blocklist matching "/account"
    When the current URL changes to one matching "/account"
    Then session recording should be paused

  @url_capable
  Scenario: Navigating away from a blocklisted URL resumes recording
    Given the SDK is initialized with token "test-token" and session replay enabled and active
    And the remote config configures a URL blocklist matching "/account"
    And recording is paused because the current URL matches "/account"
    When the current URL changes to one that does not match "/account"
    Then session recording should resume

  # Minimum-duration buffering gate

  Scenario: Replay data is withheld below the minimum duration
    Given the SDK is initialized with token "test-token" and session replay enabled and otherwise eligible
    And the remote config sets the minimum duration to 5000 milliseconds
    When the session has captured less than 5000 milliseconds of activity
    Then the session's replay data should not be emitted

  Scenario: Replay data is emitted once the minimum duration is reached
    Given the SDK is initialized with token "test-token" and session replay enabled and otherwise eligible
    And the remote config sets the minimum duration to 5000 milliseconds
    When the session's captured activity reaches or exceeds 5000 milliseconds
    Then the buffered replay data should be emitted

  # Restrictive (AND) combination — all replay SDKs (default; mobile-only mode)

  Scenario: Event trigger with zero sampling does not record even when the event fires
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the SDK applies the restrictive (AND) combination
    And the remote config configures event trigger "$pageview" and a sample rate of 0.0
    When the client captures an event named "$pageview"
    Then session recording should not be active because sampling did not pass

  Scenario: All configured controls satisfied records the session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the SDK applies the restrictive (AND) combination
    And the remote config configures event trigger "$pageview" and a sample rate of 1.0
    When the client captures an event named "$pageview"
    Then session recording should be active

  Scenario: Unsatisfied linked flag blocks recording even when sampled in
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the SDK applies the restrictive (AND) combination
    And the remote config links recording to boolean flag "replay-flag" and sets a sample rate of 1.0
    And feature flag "replay-flag" is not enabled for the user
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  # Permissive (OR) combination — configurable-match-type SDKs only (mobile exempt)

  @configurable_match_type
  Scenario: Matching event records at zero sampling
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger match type to "any"
    And the remote config configures event trigger "$pageview" and a sample rate of 0.0
    When the client captures an event named "$pageview"
    Then session recording should be active

  @configurable_match_type
  Scenario: Sampled-in session records before any trigger fires
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger match type to "any"
    And the remote config configures event trigger "$pageview" and a sample rate of 1.0
    When the SDK resolves whether to record the current session before "$pageview" is captured
    Then session recording should be active

  @configurable_match_type
  Scenario: No control satisfied does not record
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger match type to "any"
    And the remote config configures event trigger "$pageview" and a sample rate of 0.0
    When the SDK resolves whether to record the current session before "$pageview" is captured
    Then session recording should not be active

  # Hybrid (multi-layer) SDKs — managed layer over an embedded native replay SDK

  @hybrid
  Scenario: Managed-layer event activates replay in the native layer
    Given a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
    And session replay is enabled
    And the remote config configures event trigger "$pageview"
    And session recording is not active because the trigger has not fired
    When the client captures an event named "$pageview" on the managed layer
    Then the event name should be forwarded to the layer that matches event triggers
    And session recording should be active

  @hybrid
  Scenario: Layers share one session id for a consistent decision
    Given a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
    And session replay is enabled
    And the remote config sets the recording sample rate to 0.0
    When the managed and native layers resolve whether to record the current session
    Then both layers should use the same session id
    And both layers should reach the same sampling decision
