@private @canonical_behavior @acceptance @before_send_hook @both
Feature: Before Send Hook
  Acceptance tests for the canonical before send hook behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Before-send can mutate an assembled event before enqueue
    Given the SDK is initialized with token "test-token"
    And before-send adds property "privacy" with value "filtered"
    When capture is called with event "Checkout Started"
    Then one event named "Checkout Started" should be enqueued
    And the enqueued event property "privacy" should equal "filtered"

  Scenario: Before-send can drop an event
    Given the SDK is initialized with token "test-token"
    And before-send drops events named "Secret Event"
    When capture is called with event "Secret Event"
    Then no event named "Secret Event" should be enqueued

  Scenario: Before-send exceptions do not crash callers
    Given the SDK is initialized with token "test-token"
    And before-send throws an exception
    When capture is called with event "Safe Event"
    Then the capture call should not throw
    And the SDK should record a before-send warning
