@public @canonical_behavior @acceptance @reset @client
Feature: Reset
  Acceptance tests for the canonical reset behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Reset clears identified state and creates a fresh anonymous identity
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    And the current anonymous id is "anon-123"
    When reset is called with anonymous id regeneration enabled
    Then get distinct id should not return "user-123"
    And get anonymous id should not return "anon-123"
    And registered groups should be empty

  Scenario: Reset clears super properties and group context
    Given the SDK is initialized with token "test-token"
    And registered properties are:
      | property | value |
      | plan     | pro   |
    And group context contains type "company" and key "company-123"
    When reset is called
    Then registered properties should be empty
    And registered groups should be empty

  Scenario: Reset starts a new session for subsequent events
    Given the SDK is initialized with token "test-token"
    And the current session id is "session-123"
    When reset is called
    And get session id is called
    Then the returned session id should not be "session-123"
