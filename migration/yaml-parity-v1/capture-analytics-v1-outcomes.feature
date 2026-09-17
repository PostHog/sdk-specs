@public @acceptance @both @capture @api_capture_v1
Feature: Analytics-v1 partial outcomes and default omission YAML parity
  HTTP responses drive retries; assertions retain the source observation scopes.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:handles_200_full_success
  Scenario: Full success produces one request after two seconds
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:handles_200_with_all_ok
  Scenario: All ok results produce one request after three seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","ok","ok"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 3000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:does_not_retry_dropped_events
  Scenario: Dropped events are not retried
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["drop","drop"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 3000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:does_not_retry_limited_events
  Scenario: Limited events are not retried
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","limited"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 3000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:prunes_ok_events_on_partial_retry
  Scenario: Ok UUIDs are pruned from the first partial retry
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the second request should retain first-response retry UUIDs and omit its terminal UUIDs

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:prunes_dropped_events_on_partial_retry
  Scenario: Dropped UUIDs are pruned from the first partial retry
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["drop","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the second request should retain first-response retry UUIDs and omit its terminal UUIDs

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:retries_only_retry_events_from_partial
  Scenario: Mixed outcomes prune terminal UUIDs and leave one event in the last batch
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","drop","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the second request should retain first-response retry UUIDs and omit its terminal UUIDs
    And the last request should contain exactly 1 parsed events

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:partial_retry_preserves_uuids
  Scenario: Partial retries retain eligible UUIDs
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the second request should retain first-response retry UUIDs and omit its terminal UUIDs

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:partial_retry_attempt_header_increments
  Scenario: Partial retry attempts are consecutive
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And all recorded request attempts should be consecutive integers starting at one

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:partial_retry_request_id_preserved
  Scenario: Partial retries retain the request ID
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And all recorded request IDs should equal the nonempty first request ID

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:respects_retry_after_on_partial
  Scenario: Partial retries respect the first Retry-After delay
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {"Retry-After":"3"} | null | ["ok","retry"] |
      | 200 | {} | null | null |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 5000 milliseconds elapse without a public SDK call
    Then at least 2 capture request should have been received
    And the first inter-request delay should be at least 2500 milliseconds

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:unknown_result_treated_as_terminal
  Scenario: An unknown result string is terminal
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok",{"details":"some_new_detail","result":"unknown_future_result"}] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 2 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 3000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:partial_batch_handling:mixed_ok_drop_limited_no_retry
  Scenario: Mixed ok drop and limited outcomes produce one request
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 200 | {} | null | ["ok","drop","limited","ok"] |
    And the SDK is initialized with token "phc_test_key" and flush threshold 10
    When capture is called sequentially 4 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user","event":"test_event_{index}"}
      """
    And pending captures are flushed
    And 3000 milliseconds elapse without a public SDK call
    Then exactly 1 capture request should have been received

  # Source: yaml:029a94a:capture_v1:compression:no_content_encoding_when_disabled
  Scenario: Explicitly disabled compression omits the first request encoding header
    Given the SDK is initialized with token "phc_test_key", flush threshold 1, and compression disabled
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "Content-Encoding" should be absent

  # Source: yaml:029a94a:capture_v1:error_handling:does_not_retry_on_unknown_4xx
  Scenario: HTTP 403 is terminal after two seconds
    Given the mock serves these ordered analytics responses:
      | status | headers | body | event_results |
      | 403 | {} | "{\"error\":\"forbidden\",\"error_description\":\"Forbidden\",\"error_uri\":\"https://posthog.com/docs/api\"}" | null |
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    And 2000 milliseconds elapse without a public SDK call
    Then exactly one recorded request excluding paths containing /flags should have been received

  # Source: yaml:029a94a:capture_v1:event_options:unset_options_omitted
  Scenario: Unset control options are omitted from the first event
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event option "cookieless_mode" should be absent
    And the first received event option "disable_skew_correction" should be absent
    And the first received event option "process_person_profile" should be absent
    And the first received event option "product_tour_id" should be absent

  # Source: yaml:029a94a:capture_v1:geoip_and_historical_migration:historical_migration_set_in_body
  Scenario: Historical migration is set at the batch root
    Given the SDK is initialized with token "phc_test_key", flush threshold 1, and historical migration enabled
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should contain historical_migration equal to true

  # Source: yaml:029a94a:capture_v1:geoip_and_historical_migration:historical_migration_absent_by_default
  Scenario: Historical migration is absent by default
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should omit these root fields:
      | field |
      | historical_migration |
