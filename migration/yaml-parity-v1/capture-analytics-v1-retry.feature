@public @acceptance @capture @api_capture_v1 @requires:capture_v1
Feature: Analytics-v1 retries and mock response YAML parity
  Request observations and mock-authored response checks are distinct evidence layers.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # Source: yaml:029a94a:capture_v1:deduplication:preserves_uuid_on_retry
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

  # Source: yaml:029a94a:capture_v1:deduplication:preserves_timestamp_on_retry
  Scenario: Present timestamp lists match across the first retry
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
    Then the present event "timestamp" lists in requests zero and one should be identical

  # Source: yaml:029a94a:capture_v1:deduplication:preserves_uuid_and_timestamp_on_batch_retry
  Scenario: A retried batch preserves its first two identity lists without duplicate UUIDs
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

  # Source: yaml:029a94a:capture_v1:deduplication:no_duplicate_events_in_batch
  Scenario: Each received batch has no duplicate nonempty UUIDs
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 5 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then at least 1 capture request should have been received
    And every received batch should have no duplicate nonempty UUIDs

  # Source: yaml:029a94a:capture_v1:header_behavior_on_retry:attempt_header_starts_at_one
  Scenario: The initial attempt header is one
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Attempt" should be integer 1

  # Source: yaml:029a94a:capture_v1:header_behavior_on_retry:attempt_header_increments_on_retry
  Scenario: Attempt headers increase across all recorded requests
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
    And all recorded request attempts should be consecutive integers starting at one

  # Source: yaml:029a94a:capture_v1:header_behavior_on_retry:request_id_preserved_on_retry
  Scenario: Retries preserve the first nonempty request ID
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
    Then at least 2 capture request should have been received
    And all recorded request IDs should equal the nonempty first request ID

  # Source: yaml:029a94a:capture_v1:header_behavior_on_retry:different_requests_have_different_request_ids
  Scenario: Independent flushes have different request IDs
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event_1"}
      """
    And pending captures are flushed
    And 1000 milliseconds elapse without a public SDK call
    And capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event_2"}
      """
    And pending captures are flushed
    And 1000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the first two request headers "posthog-request-id" should be nonempty and different

  # Source: yaml:029a94a:capture_v1:header_behavior_on_retry:request_timestamp_changes_on_retry
  Scenario: The first retry has a different request timestamp
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
    Then at least 2 capture request should have been received
    And the first two request headers "posthog-request-timestamp" should be nonempty and different

  # Source: yaml:029a94a:capture_v1:response_format_validation:success_response_has_uuid_keyed_results
  Scenario: The mock success response has a results object
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first mock-authored response should have status 200
    And the first mock-authored response should contain a results object

  # Source: yaml:029a94a:capture_v1:response_format_validation:success_response_has_ok_for_each_event
  Scenario: The mock success response has three ok results
    Given the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first mock-authored response should contain a results object
    And every first mock-authored response result should equal "ok"
    And the first mock-authored response should contain exactly 3 results

  # Source: yaml:029a94a:capture_v1:response_format_validation:success_no_retry_after_when_all_ok
  Scenario: The mock all-ok response omits Retry-After
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","ok"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first mock-authored response Retry-After should be absent

  # Source: yaml:029a94a:capture_v1:response_format_validation:success_retry_after_present_when_retry_events
  Scenario: The mock response with a retry result includes Retry-After
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","retry"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first mock-authored response Retry-After should be present

  # Source: yaml:029a94a:capture_v1:response_format_validation:success_no_retry_after_when_drop_only
  Scenario: The mock ok and drop response omits Retry-After
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","drop"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    Then the first mock-authored response Retry-After should be absent

  # Source: yaml:029a94a:capture_v1:response_format_validation:response_echoes_request_id
  Scenario: The mock response echoes the sent request ID
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first mock-authored response should echo the nonempty sent request ID

  # Source: yaml:029a94a:capture_v1:retry_behavior:retries_on_408
  Scenario: HTTP 408 is retried and a 200 is observed
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 408 | {} | "{\\"error\\":\\"body_read_timeout\\",\\"error_description\\":\\"Body read timeout\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
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

  # Source: yaml:029a94a:capture_v1:retry_behavior:retries_on_500
  Scenario: HTTP 500 is retried and a 200 is observed
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 500 | {} | "{\\"error\\":\\"internal_error\\",\\"error_description\\":\\"Internal error\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
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

  # Source: yaml:029a94a:capture_v1:retry_behavior:retries_on_503
  Scenario: Two HTTP 503 responses are retried and a 200 is observed
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | "{\\"error\\":\\"service_unavailable\\",\\"error_description\\":\\"Service unavailable\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
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

  # Source: yaml:029a94a:capture_v1:retry_behavior:retries_on_504
  Scenario: HTTP 504 is retried and a 200 is observed
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 504 | {} | "{\\"error\\":\\"gateway_timeout\\",\\"error_description\\":\\"Gateway timeout\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
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

  # Source: yaml:029a94a:capture_v1:retry_behavior:retryable_errors_have_retry_after
  Scenario: The mock HTTP 503 response includes Retry-After
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then the first mock-authored response Retry-After should be present

  # Source: yaml:029a94a:capture_v1:retry_behavior:respects_retry_after_on_retryable_error
  Scenario: Retry-After three seconds yields a first delay of at least 2500 milliseconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 503 | {"Retry-After":"3"} | null | null |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 8000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the first inter-request delay should be at least 2500 milliseconds

  # Source: yaml:029a94a:capture_v1:retry_behavior:does_not_retry_on_400
  Scenario: HTTP 400 produces only one non-flags request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 400 | {} | "{\\"error\\":\\"missing_required_headers\\",\\"error_description\\":\\"Missing headers\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:retry_behavior:does_not_retry_on_401
  Scenario: HTTP 401 produces only one non-flags request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 401 | {} | "{\\"error\\":\\"missing_authorization\\",\\"error_description\\":\\"Unauthorized\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:retry_behavior:does_not_retry_on_402
  Scenario: HTTP 402 produces only one non-flags request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 402 | {} | "{\\"error\\":\\"billing_limit_exceeded\\",\\"error_description\\":\\"Billing limit exceeded\\",\\"error_uri\\":\\"https://posthog.com/docs/billing/limits\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:retry_behavior:does_not_retry_on_413
  Scenario: HTTP 413 produces only one non-flags request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 413 | {} | "{\\"error\\":\\"payload_too_large\\",\\"error_description\\":\\"Too large\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:retry_behavior:does_not_retry_on_415
  Scenario: HTTP 415 produces only one non-flags request after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 415 | {} | "{\\"error\\":\\"unsupported_content_type\\",\\"error_description\\":\\"Unsupported\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:retry_behavior:non_retryable_errors_have_no_retry_after
  Scenario: The mock HTTP 401 response omits Retry-After
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 401 | {} | "{\\"error\\":\\"missing_authorization\\",\\"error_description\\":\\"Unauthorized\\",\\"error_uri\\":\\"https://posthog.com/docs/api\\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then the first mock-authored response Retry-After should be absent

  # Source: yaml:029a94a:capture_v1:retry_behavior:implements_backoff
  Scenario: The first retry delay is at least 100 milliseconds
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

  # Source: yaml:029a94a:capture_v1:retry_behavior:max_retries_respected
  Scenario: Three configured retries produce exactly four requests after fifteen seconds
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
