@private @canonical_behavior @acceptance @session_replay_privacy @client
Feature: Session Replay Privacy
  Acceptance tests for the canonical session replay privacy behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Replay privacy masks text in masked elements
    Given the SDK is initialized with token "test-token" and session recording is active
    When a replay snapshot is captured for an element marked as masked containing text "secret"
    Then the replay snapshot should not contain text "secret"
    And the replay snapshot should contain masked text only

  Scenario: Replay privacy excludes no-capture elements
    Given the SDK is initialized with token "test-token" and session recording is active
    When a replay snapshot is captured for an element marked no-capture
    Then the replay snapshot should not include that element or its descendants

  Scenario: Replay privacy redacts sensitive inputs by default
    Given the SDK is initialized with token "test-token" and session recording is active
    When a replay snapshot is captured for a password input containing "secret-password"
    Then the replay snapshot should not contain text "secret-password"

  Scenario: Privacy rules apply before replay data is queued
    Given the SDK is initialized with token "test-token" and session recording is active
    When a replay snapshot containing masked text is processed
    Then queued replay data should already be redacted
