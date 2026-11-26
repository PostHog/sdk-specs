@public @canonical_behavior @acceptance @stop_session_recording @client
Feature: Stop Session Recording
  Acceptance tests for the canonical stop session recording behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Stop session recording deactivates replay capture
    Given the SDK is initialized with token "test-token"
    And session recording is active
    When stop session recording is called
    Then session recording should be inactive
    And is session replay active should return false

  Scenario: Stop session recording finalizes pending replay data
    Given the SDK is initialized with token "test-token"
    And session recording is active with pending replay data
    When stop session recording is called
    Then pending replay data should be finalized before the recorder stops
    And no new replay snapshots should be captured

  Scenario: Stop session recording is safe when inactive
    Given the SDK is initialized with token "test-token"
    And session recording is inactive
    When stop session recording is called
    Then the call should not throw
    And session recording should remain inactive

  Scenario: A remote config load does not resume a stopped recording
    Given the SDK is initialized with token "test-token"
    And session replay is configured and eligible to start
    And session recording is active
    When stop session recording is called
    And remote config is reloaded
    Then session recording should remain inactive
    When start session recording is called
    Then session recording should be active
