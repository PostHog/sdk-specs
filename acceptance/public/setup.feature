@public @canonical_behavior @acceptance @setup @both
Feature: Setup
  Acceptance tests for the canonical setup behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Setup initializes storage transport queue and identity state
    Given the SDK has not been initialized
    When setup is called with token "test-token" and host "https://mock.posthog.test"
    Then the SDK should be initialized
    And persistent storage should be available
    And the event queue should be available
    And get distinct id should return a non-empty value

  @client
  Scenario: Setup restores persisted local state
    Given persistent storage contains anonymous id "anon-123"
    And persistent storage contains registered properties:
      | property | value |
      | plan     | pro   |
    When setup is called with token "test-token" and host "https://mock.posthog.test"
    Then get anonymous id should return "anon-123"
    And registered property "plan" should equal "pro"

  @client
  Scenario: Repeated setup does not duplicate singleton state
    Given setup is called with token "test-token" and host "https://mock.posthog.test"
    When setup is called again with token "test-token" and host "https://mock.posthog.test"
    Then exactly one active SDK instance should exist for the default name
    And lifecycle observers should be installed at most once

  @both
  Scenario: Setup super properties are available immediately for the first captured event
    When setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
      | property    | value      |
      | environment | production |
      | app         | consumer   |
    And capture is called with event "First Action"
    Then the enqueued event properties should include:
      | property    | value      |
      | environment | production |
      | app         | consumer   |

  @both
  Scenario: Per-event properties override setup super properties
    When setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
      | property    | value      |
      | environment | production |
      | region      | us         |
    And capture is called with event "Override Check" and properties:
      | property    | value   |
      | environment | staging |
    Then the enqueued event properties should include:
      | property    | value   |
      | environment | staging |
      | region      | us      |

  @client
  Scenario: Setup super properties overwrite matching persisted keys while preserving other persisted keys
    Given persistent storage contains registered properties:
      | property    | value   |
      | environment | staging |
      | plan        | pro     |
    When setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
      | property    | value      |
      | environment | production |
    And capture is called with event "Relaunched"
    Then the enqueued event properties should include:
      | property    | value      |
      | environment | production |
      | plan        | pro        |

  @client
  Scenario: Setup super properties apply before bootstrap identity reconciliation
    Given the existing local user is anonymous with distinct id "anon-abc"
    When setup is called with token "test-token", host "https://mock.posthog.test", bootstrap identified distinct id "user-123", and super properties:
      | property    | value      |
      | environment | production |
    Then the enqueued "$identify" event properties should include:
      | property    | value      |
      | environment | production |

  @client
  Scenario: Setup super properties apply when starting opted out without emitting events
    When setup is called with token "test-token", host "https://mock.posthog.test", opt-out enabled, and super properties:
      | property    | value      |
      | environment | production |
    Then no events should be enqueued
    When opt-in is called
    And capture is called with event "After Consent"
    Then the enqueued "After Consent" event properties should include:
      | property    | value      |
      | environment | production |

  @client
  Scenario: Setup super properties do not mutate events already persisted from a prior launch
    Given persistent storage contains a queued event named "Prior Crash" with property "environment" equal to "staging"
    When setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
      | property    | value      |
      | environment | production |
    And flush is called
    Then the delivered "Prior Crash" event property "environment" should equal "staging"
