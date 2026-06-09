@public @canonical_behavior @acceptance @alias @both
Feature: Alias
  Acceptance tests for the canonical alias behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client alias links the current anonymous identity to a known identity
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "anon-123"
    When alias is called with alias "user-123"
    Then one event named "$create_alias" should be enqueued
    And the enqueued event distinct id should be "anon-123"
    And the enqueued event properties should include:
      | property    | value    |
      | alias       | user-123 |
      | distinct_id | anon-123 |

  @server
  Scenario: Server alias links explicit previous and new identities
    Given the SDK is initialized with token "test-token"
    When alias is called with previous distinct id "anon-123" and distinct id "user-123"
    Then one event named "$create_alias" should be enqueued
    And the enqueued event distinct id should be "anon-123"
    And the enqueued event properties should include:
      | property | value    |
      | alias    | user-123 |

  @both
  Scenario: Alias is dropped when required identities are missing
    Given the SDK is initialized with token "test-token"
    When alias is called without a previous distinct id
    Then no event should be enqueued
    And the SDK should record a validation warning
