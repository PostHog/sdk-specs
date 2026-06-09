@public @canonical_behavior @acceptance @get_distinct_id @both
Feature: Get Distinct ID
  Acceptance tests for the canonical get distinct id behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client distinct id starts as the anonymous id
    Given the SDK is initialized with token "test-token"
    And the current anonymous id is "anon-123"
    When get distinct id is called
    Then the returned distinct id should be "anon-123"

  @client
  Scenario: Client distinct id changes after identify
    Given the SDK is initialized with token "test-token"
    When identify is called with distinct id "user-123"
    And get distinct id is called
    Then the returned distinct id should be "user-123"

  @server
  Scenario: Server SDKs do not expose ambient distinct id state
    Given the SDK is initialized with token "test-token"
    When get distinct id is called on a server SDK
    Then the SDK should report that no ambient distinct id is available
