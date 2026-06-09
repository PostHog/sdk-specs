@public @canonical_behavior @acceptance @get_anonymous_id @client
Feature: Get Anonymous ID
  Acceptance tests for the canonical get anonymous id behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Anonymous id is generated on first initialization
    Given the SDK is initialized with token "test-token"
    When get anonymous id is called
    Then the returned anonymous id should not be empty
    And persistent storage should contain the same anonymous id

  Scenario: Anonymous id remains stable after identify
    Given the SDK is initialized with token "test-token"
    And the current anonymous id is "anon-123"
    When identify is called with distinct id "user-123"
    And get anonymous id is called
    Then the returned anonymous id should be "anon-123"
    And get distinct id should return "user-123"

  Scenario: Anonymous id rotates when reset requests a new device id
    Given the SDK is initialized with token "test-token"
    And the current anonymous id is "anon-123"
    When reset is called with anonymous id regeneration enabled
    And get anonymous id is called
    Then the returned anonymous id should not be "anon-123"
