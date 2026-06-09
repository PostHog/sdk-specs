@private @canonical_behavior @acceptance @persistent_storage @client
Feature: Persistent Storage
  Acceptance tests for the canonical persistent storage behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Storage persists and restores identity data
    Given the SDK is initialized with token "test-token"
    And the current anonymous id is "anon-123"
    When the SDK is restarted
    Then get anonymous id should return "anon-123"

  Scenario: Storage persists super properties
    Given the SDK is initialized with token "test-token"
    When register is called with properties:
      | property | value |
      | plan     | pro   |
    And the SDK is restarted
    And capture is called with event "Loaded"
    Then the enqueued event property "plan" should equal "pro"

  Scenario: Storage failures do not crash SDK calls
    Given the SDK is initialized with token "test-token"
    And persistent storage writes will fail
    When register is called with properties:
      | property | value |
      | plan     | pro   |
    Then the call should not throw
    And the SDK should record a storage warning
