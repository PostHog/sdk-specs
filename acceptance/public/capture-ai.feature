@public @canonical_behavior @acceptance @capture-ai @server
Feature: Capture AI
  Acceptance tests for the canonical capture_ai behavior across PostHog server SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @server
  Scenario: capture_ai returns the event uuid and rides the AI route
    Given the SDK is initialized with token "test-token"
    When capture_ai is called with distinct id "user-123", event "$ai_generation", and properties:
      | property  | value |
      | $ai_model | gpt   |
    Then one event named "$ai_generation" should be enqueued on the AI route
    And the call should return the enqueued event's uuid
    And the enqueued event should include a timestamp and uuid

  @server
  Scenario: capture and capture_ai ride separate routes
    Given the SDK is initialized with token "test-token"
    When capture is called with distinct id "user-123", event "button_clicked"
    And capture_ai is called with distinct id "user-123", event "$ai_generation"
    And the SDK is flushed
    Then the analytics batch endpoint should receive only "button_clicked"
    And the AI batch endpoint should receive only "$ai_generation"

  @server
  Scenario: capture never reroutes AI-named events
    Given the SDK is initialized with token "test-token"
    When capture is called with distinct id "user-123", event "$ai_generation"
    And the SDK is flushed
    Then the analytics batch endpoint should receive "$ai_generation"
    And the AI batch endpoint should receive no events
