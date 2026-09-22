@public @black_box @sdk:server
Feature: Server alias delivery
  Public alias calls deliver the relationship between two explicit identities.

  Background:
    Given an isolated SDK with empty persistent storage
    And the SDK is initialized with token "test-token" and flush threshold 20

  @case:black-box:server:alias:<case_id>
  Scenario Outline: Alias delivers the previous identity and its target
    When alias is called with JSON arguments:
      """application/json
      {"distinct_id":"<previous_id>","alias":"<alias>"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 1 parsed events
    And the first received event field "event" should equal "$create_alias"
    And the first received event field "distinct_id" should equal "<previous_id>"
    And the first received event property "alias" should equal "<alias>"

    Examples:
      | case_id       | previous_id | alias       |
      | signup        | anon-123    | user-123    |
      | second-person | temporary-7 | customer-42 |
