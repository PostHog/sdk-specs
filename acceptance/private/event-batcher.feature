@private @canonical_behavior @acceptance @event_batcher @both
Feature: Event Batcher
  Acceptance tests for the canonical event batcher behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Batcher flushes when batch size threshold is reached
    Given the SDK is initialized with token "test-token" and flush at is 2
    When capture is called with event "First"
    And capture is called with event "Second"
    Then the mock server should receive a batch containing events:
      | event  |
      | First  |
      | Second |
    And the event queue should be empty after a successful flush

  Scenario: Batcher flushes when interval elapses
    Given the SDK is initialized with token "test-token" and flush interval is "10 seconds"
    When capture is called with event "Delayed"
    And the SDK clock advances by "10 seconds"
    Then the mock server should receive a batch containing events:
      | event   |
      | Delayed |

  Scenario: Batcher preserves FIFO order within a batch
    Given the SDK is initialized with token "test-token" and flush at is 3
    When capture is called with event "First"
    And capture is called with event "Second"
    And capture is called with event "Third"
    Then the mock server should receive events in order:
      | event  |
      | First  |
      | Second |
      | Third  |
