@public @black_box @sdk:server
Feature: Server identify delivery
  Public identify calls deliver profile updates after an explicit flush.

  Background:
    Given an isolated SDK with empty persistent storage
    And the SDK is initialized with token "test-token" and flush threshold 20

  @case:black-box:server:identify:<case_id>
  Scenario Outline: Identify delivers the supplied identity and user properties
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
      | case_id          | distinct_id | properties                                                              |
      | scalar-values    | user-123    | {"email":"user@example.test","active":false,"score":0,"note":null} |
      | nested-values    | user-456    | {"preferences":{"theme":"dark"},"tags":["beta","team"]}          |
