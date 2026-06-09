@public @canonical_behavior @acceptance @is_session_replay_active @client
Feature: Is Session Replay Active
  Acceptance tests for the canonical is session replay active behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Replay active reports false before recording starts
    Given the SDK is initialized with token "test-token"
    When is session replay active is called
    Then the returned replay active value should be false

  Scenario: Replay active reports true after manual start
    Given the SDK is initialized with token "test-token"
    And session replay is configured and eligible to start
    When start session recording is called
    And is session replay active is called
    Then the returned replay active value should be true

  Scenario: Replay active reports false after manual stop
    Given the SDK is initialized with token "test-token"
    And session recording is active
    When stop session recording is called
    And is session replay active is called
    Then the returned replay active value should be false
