@public @canonical_behavior @acceptance @group_identify @both
Feature: Group Identify
  Acceptance tests for the canonical group identify behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Group identify emits a group profile update event
    Given the SDK is initialized with token "test-token"
    When group identify is called with type "company", key "company-123", and properties:
      | property | value |
      | plan     | pro   |
    Then one event named "$groupidentify" should be enqueued
    And the enqueued event properties should include:
      | property     | value       |
      | $group_type  | company     |
      | $group_key   | company-123 |
      | plan         | pro         |

  @both
  Scenario: Group identify requires type and key
    Given the SDK is initialized with token "test-token"
    When group identify is called without a group key
    Then no event named "$groupidentify" should be enqueued
    And the SDK should record a validation warning

  @client
  Scenario: Group identify does not replace registered group context
    Given the SDK is initialized with token "test-token"
    When group identify is called with type "company", key "company-123", and no properties
    Then registered groups should not change
