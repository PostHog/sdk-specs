@public @canonical_behavior @acceptance @start_session_recording @client
Feature: Start Session Recording
  Acceptance tests for the canonical start session recording behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Start session recording activates replay capture
    Given the SDK is initialized with token "test-token"
    And session replay is configured and eligible to start
    And session recording is inactive
    When start session recording is called
    Then session recording should be active
    And is session replay active should return true
    And replay snapshots should include the current session id

  Scenario: Start session recording is idempotent
    Given the SDK is initialized with token "test-token"
    And session replay is configured and eligible to start
    And session recording is active
    When start session recording is called
    Then session recording should remain active
    And duplicate replay recorders should not be installed

  Scenario: Start session recording respects opt-out state
    Given the SDK is initialized with token "test-token"
    And session replay is configured and eligible to start
    And analytics capture is opted out
    When start session recording is called
    Then session recording should remain inactive
