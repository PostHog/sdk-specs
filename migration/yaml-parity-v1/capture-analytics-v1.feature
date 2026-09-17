@public @acceptance @both @capture @api_capture_v1 @requires:capture_v1
Feature: Analytics-v1 wire YAML parity
  Analytics-v1 API support is declared independently of runtime and identity model.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the SDK is initialized with token "phc_test_key" and flush threshold 1

  @case:migration:yaml-parity-v1:capture_analytics_v1:targets_v1_endpoint
  Scenario: Requests target the analytics-v1 endpoint
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And every capture request path should be one of:
      | path                   |
      | /i/v1/analytics/events |

  @case:migration:yaml-parity-v1:capture_analytics_v1:does_not_use_legacy_endpoints
  Scenario: Requests avoid the five legacy endpoints
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    And no capture request should use "/batch"
    And no capture request should use "/e"
    And no capture request should use "/capture"
    And no capture request should use "/track"
    And no capture request should use "/i/v0/e"

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_authorization_bearer_header
  Scenario: The first request authenticates with the configured bearer token
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request should authenticate with bearer token "phc_test_key"

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_content_type_json
  Scenario: The first content type starts with application/json
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "Content-Type" should match "^application/json"

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_posthog_sdk_info_format
  Scenario: The first SDK-info header has text on either side of a slash
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Sdk-Info" should match "^.+/.+$"

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_posthog_attempt_header
  Scenario: The first attempt header parses as integer one
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Attempt" should be integer 1

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_posthog_request_id
  Scenario: The first request ID parses as a UUID
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Request-Id" should be a valid UUID

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_posthog_request_timestamp
  Scenario: The first request timestamp is canonical UTC
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Request-Timestamp" should be a canonical UTC timestamp

  @case:migration:yaml-parity-v1:capture_analytics_v1:has_user_agent
  Scenario: The first request has a nonempty user agent
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "User-Agent" should match "^.+$"

  @case:migration:yaml-parity-v1:capture_analytics_v1:body_has_created_at_and_batch
  Scenario: The first envelope has UTC created_at and a nonempty batch
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should have a canonical UTC created_at and a nonempty batch array

  @case:migration:yaml-parity-v1:capture_analytics_v1:no_api_key_in_body
  Scenario: The first body omits root api_key and token
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should omit these root fields:
      | field   |
      | api_key |
      | token   |

  @case:migration:yaml-parity-v1:capture_analytics_v1:no_sent_at_in_body
  Scenario: The first body omits root sent_at
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should omit these root fields:
      | field   |
      | sent_at |

  @case:migration:yaml-parity-v1:capture_analytics_v1:event_has_required_root_fields
  Scenario: Every first-request event contains the four required root fields
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then every event in the first capture request should contain these root fields:
      | field       |
      | event       |
      | uuid        |
      | distinct_id |
      | timestamp   |

  @case:migration:yaml-parity-v1:capture_analytics_v1:event_uuid_is_valid
  Scenario: The first received event UUID is valid
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event UUID should be valid

  @case:migration:yaml-parity-v1:capture_analytics_v1:event_timestamp_is_rfc3339
  Scenario: Every first-request event timestamp is canonical UTC
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have a canonical UTC timestamp

  @case:migration:yaml-parity-v1:capture_analytics_v1:non_utc_event_timestamp_is_converted_to_utc
  Scenario: Timestamp overrides normalize the instant without rewriting property strings
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"timestamp_like":"2025-01-02T08:34:05+05:30"},"timestamp":"2025-01-02T08:34:05+05:30"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05Z"
    And the first received event property "timestamp_like" should equal "2025-01-02T08:34:05+05:30"

  @case:migration:yaml-parity-v1:capture_analytics_v1:distinct_id_is_string
  Scenario: The first received distinct_id is a string
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user_123","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event field "distinct_id" should be a string

  @case:migration:yaml-parity-v1:capture_analytics_v1:distinct_id_at_root_not_properties
  Scenario: The first received distinct_id is at root and not in properties
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain "distinct_id" at root and not in properties
