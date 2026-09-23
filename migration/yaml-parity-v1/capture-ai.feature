@public @acceptance @capture-ai @api_capture_ai_v0 @requires:capture_ai_v0
Feature: AI capture YAML parity
  AI v0 applicability is independent of runtime and the analytics protocol.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the SDK is initialized with token "phc_test_key" and flush threshold 1

  Scenario: AI capture uses the dedicated v0 endpoint
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path            |
      | /i/v0/ai/batch/ |
    And the first received event field "event" should equal "$ai_generation"

  Scenario: Ordinary capture does not reroute AI-named events
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path                   |
      | /batch                 |
      | /i/v1/analytics/events |
    And no capture request should use "/i/v0/ai/batch/"

  Scenario: AI capture returns the generated wire UUID
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation"}
      """
    Then AI capture should return an admitted event UUID
    When pending captures are flushed
    Then the first received event UUID should be valid
    And the AI capture return should equal the first received event UUID

  Scenario: AI capture preserves a supplied UUID in its return and on the wire
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation","uuid":"0198c0de-0000-7000-8000-000000000abc"}
      """
    Then AI capture should return an admitted event UUID
    And the AI capture return should equal "0198c0de-0000-7000-8000-000000000abc"
    When pending captures are flushed
    Then the first received event field "uuid" should equal "0198c0de-0000-7000-8000-000000000abc"
    And the AI capture return should equal the first received event UUID

  Scenario: AI timestamps normalize the instant without rewriting property strings
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation","timestamp":"2025-01-02T08:34:05+05:30","properties":{"timestamp_like":"2025-01-02T08:34:05+05:30"}}
      """
    And pending captures are flushed
    Then every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05Z"
    And the first received event property "timestamp_like" should equal "2025-01-02T08:34:05+05:30"
