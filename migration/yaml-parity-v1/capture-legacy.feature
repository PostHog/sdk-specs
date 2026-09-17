@public @acceptance @both @capture @api_capture_v0
Feature: Legacy capture wire and retry YAML parity
  Legacy batch and event API contracts are declared independently of runtime.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # Source: yaml:029a94a:capture:format_validation:event_has_required_fields
  @api_capture_v0_batch
  Scenario: First event has the supplied event name and root identity
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first received event field "event" should equal "test_event"
    And the first received event field "distinct_id" should equal "test_user"

  # Source: yaml:029a94a:capture:format_validation:event_has_required_fields_client
  @api_capture_v0_event
  Scenario: First event has the supplied event name and properties identity
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first received event field "event" should equal "test_event"
    And the first received event property "distinct_id" should equal JSON "test_user"

  # Source: yaml:029a94a:capture:format_validation:event_has_uuid
  Scenario: First event contains a parseable UUID
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain root field "uuid"
    And the first received event UUID should be valid

  # Source: yaml:029a94a:capture:format_validation:event_has_lib_properties
  Scenario: First event contains the library property
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain property "$lib"

  # Source: yaml:029a94a:capture:format_validation:distinct_id_is_string
  @api_capture_v0_batch
  Scenario: First event root identity equals the supplied string
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user_123","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event field "distinct_id" should equal "test_user_123"

  # Source: yaml:029a94a:capture:format_validation:distinct_id_is_string_client
  @api_capture_v0_event
  Scenario: First event properties identity equals the supplied string
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user_123","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event property "distinct_id" should equal JSON "test_user_123"

  # Source: yaml:029a94a:capture:format_validation:token_is_present
  @api_capture_v0_batch
  Scenario: First request contains the token at event token or body api_key or token
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request should contain token "phc_test_key" at event token or body api_key or token

  # Source: yaml:029a94a:capture:format_validation:token_is_present_client
  @api_capture_v0_event
  Scenario: First request contains an event with token or api_key
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then an event in the first request should resolve token "phc_test_key" from event then property token or api_key

  # Source: yaml:029a94a:capture:format_validation:custom_properties_preserved
  Scenario: Custom string number and boolean properties are preserved
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"custom_bool":true,"custom_number":42,"custom_string":"hello"}}
      """
    And pending captures are flushed
    Then the first received event property "custom_string" should equal JSON "hello"
    And the first received event property "custom_number" should equal JSON 42
    And the first received event property "custom_bool" should equal JSON true

  # Source: yaml:029a94a:capture:format_validation:event_has_timestamp
  Scenario: First event contains a timestamp field
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain root field "timestamp"

  # Source: yaml:029a94a:capture:format_validation:non_utc_event_timestamp_is_converted_to_utc
  Scenario: Timestamp offset is normalized but the timestamp-like property is unchanged
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"timestamp_like":"2025-01-02T08:34:05+05:30"},"timestamp":"2025-01-02T08:34:05+05:30"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05Z"
    And the first received event property "timestamp_like" should equal JSON "2025-01-02T08:34:05+05:30"

  # Source: yaml:029a94a:capture:retry_behavior:retries_on_503
  Scenario: Two HTTP 503 responses are retried to an observed success
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | "{\"error\": \"Service unavailable\"}" | null |
      | 503 | {} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 3 capture request should have been received
    And at least one recorded response should have status 200

  # Source: yaml:029a94a:capture:retry_behavior:does_not_retry_on_400
  Scenario: HTTP 400 produces one request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 400 | {} | "{\"error\": \"Bad request\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture:retry_behavior:does_not_retry_on_401
  Scenario: HTTP 401 produces one request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 401 | {} | "{\"error\": \"Unauthorized\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture:retry_behavior:respects_retry_after_header
  Scenario: HTTP 429 respects the first Retry-After delay
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 429 | {"Retry-After":"3"} | "{\"error\": \"Rate limited\"}" | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the first inter-request delay should be at least 2500 milliseconds

  # Source: yaml:029a94a:capture:retry_behavior:implements_backoff
  Scenario: Backoff meets the first-delay floor of 100 milliseconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 15000 milliseconds elapse without a public SDK call
    Then at least 3 capture request should have been received
    And the first inter-request delay should be at least 100 milliseconds

  # Source: yaml:029a94a:capture:retry_behavior:retries_on_500
  Scenario: HTTP 500 is retried to an observed success
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 500 | {} | "{\"error\": \"Internal server error\"}" | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And at least one recorded response should have status 200

  # Source: yaml:029a94a:capture:retry_behavior:retries_on_502
  Scenario: HTTP 502 is retried to an observed success
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 502 | {} | "{\"error\": \"Bad gateway\"}" | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And at least one recorded response should have status 200

  # Source: yaml:029a94a:capture:retry_behavior:retries_on_504
  Scenario: HTTP 504 is retried to an observed success
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 504 | {} | "{\"error\": \"Gateway timeout\"}" | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And at least one recorded response should have status 200

  # Source: yaml:029a94a:capture:retry_behavior:max_retries_respected
  Scenario: Three configured retries produce exactly four requests
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and maximum retries 3
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 15000 milliseconds elapse without a public SDK call
    Then exactly 4 capture request should have been received

  # Source: yaml:029a94a:capture:deduplication:generates_unique_uuids
  Scenario: All collected UUIDs are unique
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then all present UUIDs across received requests should be unique

  # Source: yaml:029a94a:capture:deduplication:preserves_uuid_on_retry
  Scenario: Present UUID lists match across the first retry
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then the present event "uuid" lists in requests zero and one should be identical

  # Source: yaml:029a94a:capture:deduplication:preserves_uuid_and_timestamp_on_retry
  Scenario: Present UUID and timestamp lists match across the first retry
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
      | 503 | {} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 10000 milliseconds elapse without a public SDK call
    Then at least 3 capture request should have been received
    And the present event "uuid" lists in requests zero and one should be identical
    And the present event "timestamp" lists in requests zero and one should be identical

  # Source: yaml:029a94a:capture:deduplication:preserves_uuid_and_timestamp_on_batch_retry
  Scenario: Batched UUID and timestamp lists match across the first retry
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the present event "uuid" lists in requests zero and one should be identical
    And the present event "timestamp" lists in requests zero and one should be identical
    And every received batch should have no duplicate nonempty UUIDs

  # Source: yaml:029a94a:capture:deduplication:no_duplicate_events_in_batch
  Scenario: Every received batch has no duplicate nonempty UUIDs
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then at least 1 capture request should have been received
    And every received batch should have no duplicate nonempty UUIDs

  # Source: yaml:029a94a:capture:deduplication:different_events_have_different_uuids
  Scenario: The first two collected UUIDs of identical captures differ
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

  # Source: yaml:029a94a:capture:batch_format:uses_proper_batch_structure
  @api_capture_v0_batch
  Scenario: First body contains api_key and a batch array
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should contain a batch array and an api_key field

  # Source: yaml:029a94a:capture:batch_format:flush_with_no_events_sends_nothing
  Scenario: Empty flush sends no accumulated requests
    Given the SDK is initialized with token "phc_test_key" and no additional configuration
    And pending captures are flushed
    Then exactly 0 capture request should have been received

  # Source: yaml:029a94a:capture:batch_format:multiple_events_batched_together
  @api_capture_v0_batch
  Scenario: Five captures produce one request with a batch array
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And the first request body should contain a batch array

  # Source: yaml:029a94a:capture:error_handling:does_not_retry_on_403
  Scenario: HTTP 403 produces one request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 403 | {} | "{\"error\": \"Forbidden\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture:error_handling:does_not_retry_on_413
  Scenario: HTTP 413 produces one request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 413 | {} | "{\"error\": \"Payload too large\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture:error_handling:retries_on_408
  Scenario: HTTP 408 is retried to an observed success
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 408 | {} | "{\"error\": \"Request timeout\"}" | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And at least one recorded response should have status 200
