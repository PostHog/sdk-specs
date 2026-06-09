@public @canonical_behavior @acceptance @set_person_properties @client
Feature: Set Person Properties
  Acceptance tests for the canonical set person properties behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Set person properties emits profile update properties
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    When set person properties is called with properties:
      | property | value          |
      | email    | user@test.test |
    Then one event named "$set" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event property "$set.email" should equal "user@test.test"

  Scenario: Set person properties can include set-once properties
    Given the SDK is initialized with token "test-token"
    When set person properties is called with set properties:
      | property | value          |
      | email    | user@test.test |
    And set-once properties:
      | property   | value      |
      | first_seen | yesterday  |
    Then one event named "$set" should be enqueued
    And the enqueued event property "$set.email" should equal "user@test.test"
    And the enqueued event property "$set_once.first_seen" should equal "yesterday"

  Scenario: Empty person property updates do not crash
    Given the SDK is initialized with token "test-token"
    When set person properties is called with no properties
    Then the call should not throw
