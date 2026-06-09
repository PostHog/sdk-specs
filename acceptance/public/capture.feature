@public @canonical_behavior @acceptance @capture @both
Feature: Capture
  Acceptance tests for the canonical capture behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client capture enriches an event with ambient context
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    And the current session id is "session-123"
    And registered properties are:
      | property | value |
      | plan     | pro   |
    When capture is called with event "Signed Up" and properties:
      | property | value |
      | source   | ad    |
    Then one event named "Signed Up" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property    | value       |
      | source      | ad          |
      | plan        | pro         |
      | $session_id | session-123 |
    And the enqueued event should include a timestamp and uuid

  @server
  Scenario: Server capture requires an explicit distinct id
    Given the SDK is initialized with token "test-token"
    When capture is called with distinct id "user-123", event "Signed Up", and properties:
      | property | value |
      | source   | api   |
    Then one event named "Signed Up" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property | value |
      | source   | api   |
      | $lib     | any   |
    And the enqueued event should include an event uuid

  @both
  Scenario: Capture honors opt-out state
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted out
    When capture is called with event "Ignored Event"
    Then no event should be enqueued
    And no network request should be sent

  @both
  Scenario: Capture can be modified or dropped by before-send
    Given the SDK is initialized with token "test-token"
    And before-send adds property "filtered" with value "yes"
    When capture is called with event "Filtered Event"
    Then one event named "Filtered Event" should be enqueued
    And the enqueued event property "filtered" should equal "yes"
    When before-send is changed to drop every event
    And capture is called with event "Dropped Event"
    Then no event named "Dropped Event" should be enqueued
