@public @acceptance @capture-ai @api_capture_ai_v1 @requires:capture_ai_v1
Feature: AI capture v1 YAML parity
  AI capture on capture v1 is declared independently of runtime and identity model.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the SDK is initialized with token "phc_test_key" and flush threshold 1

  Scenario: AI capture uses the capture v1 AI endpoint
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation","properties":{"$ai_model":"gpt"}}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path            |
      | /i/v1/ai/events |
    And the first received event field "event" should equal "$ai_generation"
    And the first request should authenticate with bearer token "phc_test_key"

  Scenario: AI capture avoids the legacy AI endpoint
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And no capture request should use "/i/v0/ai/batch/"
    And no capture request should use "/batch"

  Scenario: Ordinary capture does not reroute AI-named events
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path                   |
      | /i/v1/analytics/events |
    And no capture request should use "/i/v1/ai/events"

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

  Scenario: AI capture sends options and strips the legacy option properties
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"$ai_generation","properties":{"$process_person_profile":false},"options":{"custom_flag":true}}
      """
    And pending captures are flushed
    Then the first received event option "custom_flag" should equal JSON true
    And the first received event option "process_person_profile" should equal JSON false
    And the first received event property "$process_person_profile" should be absent
