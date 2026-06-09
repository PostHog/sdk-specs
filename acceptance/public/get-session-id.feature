@public @canonical_behavior @acceptance @get_session_id @client
Feature: Get Session ID
  Acceptance tests for the canonical get session id behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Getting the session id creates or returns an active session
    Given the SDK is initialized with token "test-token"
    When get session id is called
    Then the returned session id should not be empty
    And capture should attach the same value as property "$session_id"

  Scenario: Session id remains stable within the inactivity timeout
    Given the SDK is initialized with token "test-token"
    And get session id returned "session-123"
    When the SDK clock advances by "10 minutes"
    And get session id is called
    Then the returned session id should be "session-123"

  Scenario: Session id rotates after inactivity timeout
    Given the SDK is initialized with token "test-token"
    And get session id returned "session-123"
    When the SDK clock advances past the session inactivity timeout
    And get session id is called
    Then the returned session id should not be "session-123"
