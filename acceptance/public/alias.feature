@public @canonical_behavior @acceptance @alias
Feature: Alias
  Acceptance tests for the canonical alias behavior across PostHog SDKs.

  @sdk:server @case:acceptance:server:alias:<case_id>
  Scenario Outline: Server alias links explicit previous and new identities
    Given an isolated SDK instance
    And the SDK is initialized with token "test-token" and flush threshold 20
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

  @client
  Scenario: Client alias links the current anonymous identity to a known identity
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    And the current distinct id is "anon-123"
    When alias is called with alias "user-123"
    Then one event named "$create_alias" should be enqueued
    And the enqueued event distinct id should be "anon-123"
    And the enqueued event properties should include:
      | property    | value    |
      | alias       | user-123 |
      | distinct_id | anon-123 |

  @both
  Scenario: Alias is dropped when required identities are missing
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    When alias is called without a previous distinct id
    Then no event should be enqueued
    And the SDK should record a validation warning
