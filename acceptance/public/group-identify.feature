@public @canonical_behavior @acceptance @group_identify
Feature: Group Identify
  Acceptance tests for the canonical group identify behavior across PostHog SDKs.

  @sdk:server @case:acceptance:server:group-identify:<case_id>
  Scenario Outline: Server group identify sends a group profile update for explicit distinct id
    Given an isolated SDK instance
    And the SDK is initialized with token "test-token" and flush threshold 20
    When group identify is called with JSON arguments:
      """application/json
      {"group_type":"company","group_key":"<group_key>","distinct_id":"<distinct_id>","properties":<properties>}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 1 parsed events
    And the first received event field "event" should equal "$groupidentify"
    And the first received event field "distinct_id" should equal "<distinct_id>"
    And the first received event property "$group_type" should equal "company"
    And the first received event property "$group_key" should equal "<group_key>"
    And the first received event property "$group_set" should equal JSON <properties>

    Examples:
      | case_id       | group_key   | distinct_id | properties                                                                                                            |
      | scalar-values | company-123 | user-123    | {"plan":"pro","active":false,"score":0,"note":null}                                                                     |
      | nested-values | company-456 | user-456    | {"preferences":{"theme":"dark"},"tags":["beta","team"],"$group_type":"literal-type","$group_key":"literal-key"}         |

  @sdk:server
  Scenario: Server group identify delivers a group identity without properties
    Given an isolated SDK instance
    And the SDK is initialized with token "test-token" and flush threshold 20
    When group identify is called with JSON arguments:
      """application/json
      {"group_type":"company","group_key":"company-123","distinct_id":"user-123"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 1 parsed events
    And the first received event field "event" should equal "$groupidentify"
    And the first received event field "distinct_id" should equal "user-123"
    And the first received event property "$group_type" should equal "company"
    And the first received event property "$group_key" should equal "company-123"

  @client
  Scenario: Group identify emits a group profile update event
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    When group identify is called with type "company", key "company-123", and properties:
      | property | value |
      | plan     | pro   |
    Then one event named "$groupidentify" should be enqueued
    And the enqueued event properties should include:
      | property        | value       |
      | $group_type     | company     |
      | $group_key      | company-123 |
      | $group_set.plan | pro         |

  @both
  Scenario: Group identify requires type and key
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    When group identify is called without a group key
    Then no event named "$groupidentify" should be enqueued
    And the SDK should record a validation warning

  @client
  Scenario: Group identify does not replace registered group context
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    When group identify is called with type "company", key "company-123", and no properties
    Then registered groups should not change
