@private @canonical_behavior @acceptance @autocapture @client
Feature: Autocapture
  Acceptance tests for the canonical autocapture behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Eligible UI interaction emits an autocapture event
    Given the SDK is initialized with token "test-token" and autocapture enabled
    When the user interacts with an element described by:
      | field      | value        |
      | tag        | button       |
      | label      | Sign up      |
      | screen     | Home         |
    Then one event named "$autocapture" should be enqueued
    And the enqueued event properties should include:
      | property       | value   |
      | $event_type    | click   |
      | $screen_name   | Home    |
    And the enqueued event should include sanitized element hierarchy metadata

  Scenario: No-capture markers suppress autocapture
    Given the SDK is initialized with token "test-token" and autocapture enabled
    When the user interacts with an element marked no-capture
    Then no event named "$autocapture" should be enqueued

  Scenario: Sensitive input values are not captured
    Given the SDK is initialized with token "test-token" and autocapture enabled
    When the user interacts with a password input containing "secret-password"
    Then no enqueued autocapture property should contain "secret-password"

  Scenario: Repeated setup does not install duplicate autocapture observers
    Given the SDK is initialized with token "test-token" and autocapture enabled
    When setup is called again with autocapture enabled
    And the user interacts with an element described by:
      | field | value  |
      | tag   | button |
    Then exactly one event named "$autocapture" should be enqueued for that interaction
