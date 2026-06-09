@private @canonical_behavior @acceptance @consent_gating @client
Feature: Consent Gating
  Acceptance tests for the canonical consent gating behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Opted out consent blocks capture and persistence writes
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted out
    When capture is called with event "Blocked"
    Then no event should be enqueued
    And no network request should be sent

  Scenario: Opted in consent allows capture
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted in
    When capture is called with event "Allowed"
    Then one event named "Allowed" should be enqueued

  Scenario: Consent state is restored before early capture calls
    Given persistent storage contains opt-out state "true"
    When the SDK is initialized with token "test-token"
    And capture is called with event "Early Event"
    Then no event named "Early Event" should be enqueued
