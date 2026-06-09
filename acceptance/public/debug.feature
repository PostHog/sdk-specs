@public @canonical_behavior @acceptance @debug @client
Feature: Debug
  Acceptance tests for the canonical debug behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Debug can be enabled and disabled at runtime
    Given the SDK is initialized with token "test-token"
    When debug is set to true
    Then SDK debug logging should be enabled
    When debug is set to false
    Then SDK debug logging should be disabled

  Scenario: Debug does not emit analytics or network traffic
    Given the SDK is initialized with token "test-token"
    When debug is set to true
    Then no event should be enqueued
    And no network request should be sent

  Scenario: Debug defaults to enabled when called without an argument
    Given the SDK is initialized with token "test-token"
    When debug is called without an enabled argument
    Then SDK debug logging should be enabled
