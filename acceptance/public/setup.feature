@public @canonical_behavior @acceptance @setup @client
Feature: Setup
  Acceptance tests for the canonical setup behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Setup initializes storage transport queue and identity state
    Given the SDK has not been initialized
    When setup is called with token "test-token" and host "https://mock.posthog.test"
    Then the SDK should be initialized
    And persistent storage should be available
    And the event queue should be available
    And get distinct id should return a non-empty value

  Scenario: Setup restores persisted local state
    Given persistent storage contains anonymous id "anon-123"
    And persistent storage contains registered properties:
      | property | value |
      | plan     | pro   |
    When setup is called with token "test-token" and host "https://mock.posthog.test"
    Then get anonymous id should return "anon-123"
    And registered property "plan" should equal "pro"

  Scenario: Repeated setup does not duplicate singleton state
    Given setup is called with token "test-token" and host "https://mock.posthog.test"
    When setup is called again with token "test-token" and host "https://mock.posthog.test"
    Then exactly one active SDK instance should exist for the default name
    And lifecycle observers should be installed at most once
