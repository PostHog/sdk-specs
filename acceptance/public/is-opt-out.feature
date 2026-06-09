@public @canonical_behavior @acceptance @is_opt_out @client
Feature: Is Opt Out
  Acceptance tests for the canonical is opt out behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Is opt out reports false by default
    Given the SDK is initialized with token "test-token"
    When is opt out is called
    Then the returned opt-out value should be false

  Scenario: Is opt out reports true after opt out
    Given the SDK is initialized with token "test-token"
    When opt out is called
    And is opt out is called
    Then the returned opt-out value should be true

  Scenario: Is opt out is restored from persistent storage
    Given persistent storage contains opt-out state "true"
    When the SDK is initialized with token "test-token"
    And is opt out is called
    Then the returned opt-out value should be true
