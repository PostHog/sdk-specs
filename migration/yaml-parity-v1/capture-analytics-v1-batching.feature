@public @acceptance @capture @api_capture_v1 @requires:capture_v1
Feature: Analytics-v1 properties and batching YAML parity
  The SDK API declaration is independent of runtime and identity model.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  Scenario: Custom scalar properties retain their values
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"custom_bool":true,"custom_number":42,"custom_string":"hello"}}
      """
    And pending captures are flushed
    Then the first received event property "custom_string" should equal JSON "hello"
    And the first received event property "custom_number" should equal JSON 42
    And the first received event property "custom_bool" should equal JSON true

  Scenario: The captured $set property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"$set":{"email":"test@example.com","name":"Test User"}}}
      """
    And pending captures are flushed
    Then the first received event property "$set" should be an object

  Scenario: The captured $set_once property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"$set_once":{"initial_referrer":"https://google.com"}}}
      """
    And pending captures are flushed
    Then the first received event property "$set_once" should be an object

  Scenario: The captured $groups property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"$groups":{"company":"posthog"}}}
      """
    And pending captures are flushed
    Then the first received event property "$groups" should be an object

  Scenario: An omitted UUID produces a present valid first-event UUID
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain root field "uuid"
    And the first received event UUID should be valid

  Scenario: Three batched events all have required root fields
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 3 parsed events
    And every event in the first capture request should contain these root fields:
      | field |
      | event |
      | uuid |
      | distinct_id |
      | timestamp |

  Scenario: The first batched event UUID is valid
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first received event UUID should be valid

  Scenario: Every first-request event timestamp is canonical UTC
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have a canonical UTC timestamp

  Scenario: The first batched distinct_id is a string
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first received event field "distinct_id" should be a string

  Scenario: The first batched distinct_id is at root and not in properties
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first received event should contain "distinct_id" at root and not in properties

  Scenario: The first batched custom scalar properties retain their values
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}","properties":{"custom_bool":true,"custom_number":42,"custom_string":"hello"}}
      """
    And pending captures are flushed
    Then the first received event property "custom_string" should equal JSON "hello"
    And the first received event property "custom_number" should equal JSON 42
    And the first received event property "custom_bool" should equal JSON true

  Scenario: The first batched $set property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}","properties":{"$set":{"email":"test@example.com","name":"Test User"}}}
      """
    And pending captures are flushed
    Then the first received event property "$set" should be an object

  Scenario: The first batched $set_once property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}","properties":{"$set_once":{"initial_referrer":"https://google.com"}}}
      """
    And pending captures are flushed
    Then the first received event property "$set_once" should be an object

  Scenario: The first batched $groups property is an object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}","properties":{"$groups":{"company":"posthog"}}}
      """
    And pending captures are flushed
    Then the first received event property "$groups" should be an object

  Scenario: The first batched UUID is present and valid and collected UUIDs are unique
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first received event should contain root field "uuid"
    And the first received event UUID should be valid
    And all present UUIDs across received requests should be unique

  Scenario: Five captures are delivered in one request
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 5 parsed events

  Scenario: A four-event batch retains the authentication and body envelope
    Given the SDK is initialized with token "phc_test_key" and flush threshold 4
    When capture is called sequentially 4 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request should contain exactly 4 parsed events
    And the first request should authenticate with bearer token "phc_test_key"
    And the first request body should have a canonical UTC created_at and a nonempty batch array

  Scenario: Empty flush leaves the accumulated request collection empty
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    And pending captures are flushed
    Then exactly 0 capture request should have been received

  Scenario: Reaching the threshold delivers a request without an explicit flush
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And 1000 milliseconds elapse without a public SDK call
    Then at least 1 capture request should have been received

  Scenario: Batch created_at is within five seconds of the real wall clock
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request created_at should be within 5 seconds of the current wall clock

  Scenario: Present UUIDs are unique across five captures
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then all present UUIDs across received requests should be unique

  Scenario: Two identical captures produce different collected UUIDs
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"key":"value"}}
      """
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"key":"value"}}
      """
    And pending captures are flushed
    Then the first two present UUIDs across received requests should differ
