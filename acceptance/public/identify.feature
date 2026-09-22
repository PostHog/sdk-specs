@public @canonical_behavior @acceptance @identify @both
Feature: Identify
  Acceptance tests for the canonical identify behavior across PostHog SDKs.

  @server @sdk:server @case:acceptance:server:identify:<case_id>
  Scenario Outline: Server identify sends a profile update for explicit distinct id
    Given an isolated SDK instance
    And the SDK is initialized with token "test-token" and flush threshold 20
    When identify is called with JSON arguments:
      """application/json
      {"distinct_id":"<distinct_id>","set":<properties>}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 1 parsed events
    And the first received event field "event" should equal "$identify"
    And the first received event field "distinct_id" should equal "<distinct_id>"
    And the first received event property "$set" should equal JSON <properties>

    Examples:
      | case_id       | distinct_id | properties                                                        |
      | scalar-values | user-123    | {"email":"user@test.test","active":false,"score":0,"note":null} |
      | nested-values | user-456    | {"preferences":{"theme":"dark"},"tags":["beta","team"]}         |

  @client
  Scenario: Client identify changes the current distinct id and sends identity properties
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @both
  Scenario: Identify validates distinct id
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    When identify is called without a distinct id
    Then identity state should not change
    And no identity event should be enqueued
