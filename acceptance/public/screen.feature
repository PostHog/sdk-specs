@public @canonical_behavior @acceptance @screen @client
Feature: Screen
  Acceptance tests for the canonical screen behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Screen records a screen view event
    Given the SDK is initialized with token "test-token"
    When screen is called with name "Home" and properties:
      | property | value |
      | tab      | main  |
    Then one event named "$screen" should be enqueued
    And the enqueued event properties should include:
      | property     | value |
      | $screen_name | Home  |
      | tab          | main  |

  Scenario: Screen updates current screen context
    Given the SDK is initialized with token "test-token"
    When screen is called with name "Settings"
    Then current screen context should be "Settings"

  Scenario: Screen respects opt-out state
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted out
    When screen is called with name "Home"
    Then no event named "$screen" should be enqueued
