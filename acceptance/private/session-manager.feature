@private @canonical_behavior @acceptance @session_manager @client
Feature: Session Manager
  Acceptance tests for the canonical session manager behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Session manager creates and reuses an active session
    Given the SDK is initialized with token "test-token"
    When the session id is requested
    Then the returned session id should not be empty
    When the session id is requested again
    Then the returned session id should be the same as the previous session id

  Scenario: Session manager rotates after inactivity timeout
    Given the SDK is initialized with token "test-token"
    And the current session id is "session-123"
    When the SDK clock advances past the session inactivity timeout
    And the session id is requested
    Then the returned session id should not be "session-123"

  Scenario: Session manager rotates after maximum session length
    Given the SDK is initialized with token "test-token"
    And the current session id is "session-123"
    When the SDK clock advances past the maximum session length
    And the session id is requested
    Then the returned session id should not be "session-123"

  Scenario: Explicit session reset starts a new session
    Given the SDK is initialized with token "test-token"
    And the current session id is "session-123"
    When the session manager resets the session
    Then the current session id should not be "session-123"
