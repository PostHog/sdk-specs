@public @acceptance @capture-ai @api_capture_ai_v1 @requires:capture_ai_v1
Feature: AI capture v1 delivery
  Misroute reporting, lane isolation, the per-event ceiling and byte batching on the capture v1 AI lane.
  Cases tagged capture_ai_v1_delivery wait for harness bindings (drop reports, log read-back and generated payloads on the v2 runner); no adapter declares that capability until they land.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  @requires:capture_ai_v1_delivery
  Scenario: A non-AI event on the AI method is sent and its misroute is reported
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    And the mock serves these ordered AI responses:
      | status | body                                                            |
      | 200    | {"results":{"*":{"result":"drop","details":"misrouted_event"}}} |
    When capture_ai is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"button_clicked"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path            |
      | /i/v1/ai/events |
    And the SDK should report the event "button_clicked" as dropped with details "misrouted_event"

  Scenario: A failing AI lane does not delay analytics delivery
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    And the mock delays every request to "/i/v1/ai/events" until released
    When capture_ai is called with distinct id "test_user" and event "$ai_generation"
    And capture is called with distinct id "test_user" and event "button_clicked"
    And 2000 milliseconds elapse without a public SDK call
    Then the analytics batch endpoint should have received "button_clicked"
    When the delayed AI request is released and succeeds
    And pending captures are flushed
    Then the AI batch endpoint should have received "$ai_generation"

  @sdk:server @requires:capture_ai_v1_delivery
  Scenario: An event at the ceiling is sent and one over it is dropped with a content-free log
    Given the SDK is initialized with token "phc_test_key" and flush threshold 2
    When capture_ai is called with event "$ai_generation" named "at-ceiling" whose properties serialize to exactly 8388608 bytes
    And capture_ai is called with event "$ai_generation" named "over-ceiling" whose properties serialize to 9437184 bytes and contain the marker "SECRET-MARKER"
    And pending captures are flushed
    Then the AI batch endpoint should receive exactly 1 event
    And the received event should be "at-ceiling"
    And the SDK should report "over-ceiling" as dropped or log its event name and byte size
    And the log output should not contain "SECRET-MARKER"

  @requires:capture_ai_v1_delivery
  Scenario: AI batches close before the byte target
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture_ai is called sequentially 3 times with an event named "gen-{index}" whose properties serialize to about 3 MiB
    And pending captures are flushed
    Then at least 2 capture request should have been received on the AI batch endpoint
    And no received request body should exceed the SDK's byte target plus envelope overhead
    And the events "gen-0", "gen-1" and "gen-2" should all have been received, in any order across the requests
