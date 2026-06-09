@public @canonical_behavior @acceptance @identify @both
Feature: Identify
  Acceptance tests for the canonical identify behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client identify changes the current distinct id and sends identity properties
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "anon-123"
    When identify is called with distinct id "user-123" and properties:
      | property | value          |
      | email    | user@test.test |
    Then get distinct id should return "user-123"
    And one event named "$identify" should be enqueued
    And the enqueued event properties should include:
      | property             | value          |
      | distinct_id          | user-123       |
      | $anon_distinct_id    | anon-123       |
      | $set.email           | user@test.test |

  @server
  Scenario: Server identify sends a profile update for explicit distinct id
    Given the SDK is initialized with token "test-token"
    When identify is called with distinct id "user-123" and properties:
      | property | value          |
      | email    | user@test.test |
    Then one event named "$identify" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event property "$set.email" should equal "user@test.test"

  @both
  Scenario: Identify validates distinct id
    Given the SDK is initialized with token "test-token"
    When identify is called without a distinct id
    Then identity state should not change
    And no identity event should be enqueued
