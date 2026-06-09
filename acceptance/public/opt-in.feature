@public @canonical_behavior @acceptance @opt_in @client
Feature: Opt In And Opt Out
  Acceptance tests for the canonical opt in and opt out behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Opt out prevents event capture and persists consent state
    Given the SDK is initialized with token "test-token"
    When opt out is called
    Then is opt out should return true
    And persistent storage should contain opt-out state "true"
    When capture is called with event "Blocked"
    Then no event should be enqueued

  Scenario: Opt in re-enables capture and persists consent state
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted out
    When opt in is called
    Then is opt out should return false
    And persistent storage should contain opt-out state "false"
    When capture is called with event "Allowed"
    Then one event named "Allowed" should be enqueued

  Scenario: Opt out can clear local persistence when configured
    Given the SDK is initialized with token "test-token"
    And persistent storage contains identity and super properties
    When opt out is called with local data clearing enabled
    Then persisted identity and super properties should be cleared
    And analytics capture should be opted out
