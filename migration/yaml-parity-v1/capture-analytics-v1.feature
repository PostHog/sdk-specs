@public @acceptance @both @capture @api_capture_v1
Feature: Analytics-v1 wire YAML parity
  Analytics-v1 API support is declared independently of runtime and identity model.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the SDK is initialized with token "phc_test_key" and flush threshold 1

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

  Scenario: The first request authenticates with the configured bearer token
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request should authenticate with bearer token "phc_test_key"

  Scenario: The first content type starts with application/json
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "Content-Type" should match "^application/json"

  Scenario: The first SDK-info header has text on either side of a slash
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Sdk-Info" should match "^.+/.+$"

  Scenario: The first attempt header parses as integer one
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Attempt" should be integer 1

  Scenario: The first request ID parses as a UUID
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Request-Id" should be a valid UUID

  Scenario: The first request timestamp is canonical UTC
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "PostHog-Request-Timestamp" should be a canonical UTC timestamp

  Scenario: The first request has a nonempty user agent
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request header "User-Agent" should match "^.+$"

  Scenario: The first envelope has UTC created_at and a nonempty batch
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should have a canonical UTC created_at and a nonempty batch array

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

  Scenario: The first body omits root sent_at
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first request body should omit these root fields:
      | field   |
      | sent_at |

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

  Scenario: The first received event UUID is valid
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event UUID should be valid

  Scenario: Every first-request event timestamp is canonical UTC
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have a canonical UTC timestamp

  Scenario: Timestamp overrides normalize the instant without rewriting property strings
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","properties":{"timestamp_like":"2025-01-02T08:34:05+05:30"},"timestamp":"2025-01-02T08:34:05+05:30"}
      """
    And pending captures are flushed
    Then every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05Z"
    And the first received event property "timestamp_like" should equal "2025-01-02T08:34:05+05:30"

  Scenario: The first received distinct_id is a string
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user_123","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event field "distinct_id" should be a string

  Scenario: The first received distinct_id is at root and not in properties
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event should contain "distinct_id" at root and not in properties
