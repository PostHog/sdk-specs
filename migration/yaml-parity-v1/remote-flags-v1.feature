@migration @yaml_parity_v1 @requires:flags_v2 @sdk:server
Feature: Native server remote flag getters
  Ordinary native server calls against the flags v2 wire API.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the server uses its native flag startup and getter behavior with no installed local definitions or results

  Scenario: Remote flag requests include the supplied person and device context
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "disable_geoip": true,
        "distinct_id": "test_user_123",
        "group_properties": {},
        "groups": {},
        "key": "signup-aa-test",
        "person_properties": {
          "$device_id": "device_abc_123"
        }
      }
      """
    And exactly 1 requests containing /flags should have been received
    And the first flags request field "token" should equal JSON "phc_test_key"
    And the first flags request field "distinct_id" should equal JSON "test_user_123"
    And the first flags request field "person_properties.$device_id" should equal JSON "device_abc_123"
    And the first flags request field "groups" should equal JSON {}
    And the first flags request field "group_properties" should equal JSON {}
    And the first flags request field "geoip_disable" should equal JSON true
    And the first flags request field "flag_keys_to_evaluate" should equal JSON ["signup-aa-test"]

  Scenario: Remote flag requests use the v2 query parameter
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And exactly 1 requests containing /flags should have been received
    And the first flags request query parameter "v" should equal "2"

  Scenario: Remote flag requests use the flags endpoint, not decide
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And exactly 1 requests containing /flags should have been received
    And no capture request should use "/decide"

  Scenario: Remote flag requests omit the Authorization header
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And exactly 1 requests containing /flags should have been received
    And the first request header "Authorization" should be absent

  Scenario: Remote flag requests contain the initialized project token
    When the SDK is initialized with token "phc_specific_key_12345" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "token" should equal JSON "phc_specific_key_12345"

  Scenario: Remote flag requests preserve groups and group properties
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "group_properties": {
          "company": {
            "plan": "enterprise"
          }
        },
        "groups": {
          "company": "acme"
        },
        "key": "any-flag"
      }
      """
    And the first flags request field "groups.company" should equal JSON "acme"
    And the first flags request field "group_properties.company.plan" should equal JSON "enterprise"

  Scenario: Omitted groups and group properties become empty objects
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "groups" should equal JSON {}
    And the first flags request field "group_properties" should equal JSON {}

  Scenario: Explicitly enabled GeoIP stays enabled in flag requests
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "disable_geoip": false,
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "geoip_disable" should equal JSON false

  Scenario: Omitted GeoIP settings default to enabled in flag requests
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "geoip_disable" should equal JSON false

  Scenario: Remote flag requests evaluate only the requested key
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "my-specific-flag"
      }
      """
    And the first flags request field "flag_keys_to_evaluate" should equal JSON ["my-specific-flag"]

  Scenario: Initialization alone does not request flags
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And exactly 0 requests containing /flags should have been received

  Scenario: Ordinary capture does not request flags
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And capture is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "event": "regular_event"
      }
      """
    And pending captures are flushed
    And exactly 0 requests containing /flags should have been received

  @requires:flags_getter_remote_uncached
  Scenario: Two uncached flag lookups make two remote requests
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And exactly 2 requests containing /flags should have been received

  Scenario: The remote flag value reaches the public getter
    When the mock serves these ordered flag responses:
      """application/json
      {
        "responses": [
          {
            "body": "{\"featureFlags\": {\"signup-aa-test\": \"variant-a\"}}",
            "status_code": 200
          }
        ]
      }
      """
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "signup-aa-test"
      }
      """
    And the public flag getter should return JSON "variant-a"

  Scenario: Remote flag lookup retries HTTP 502
    When the mock serves these ordered flag responses:
      """application/json
      {
        "responses": [
          {
            "status_code": 502
          },
          {
            "body": "{\"featureFlags\": {\"transient-502-flag\": true}}",
            "status_code": 200
          }
        ]
      }
      """
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "transient-502-flag"
      }
      """
    And exactly 2 requests containing /flags should have been received
    And the public flag getter should return JSON true

  Scenario: Remote flag lookup retries HTTP 504
    When the mock serves these ordered flag responses:
      """application/json
      {
        "responses": [
          {
            "status_code": 504
          },
          {
            "body": "{\"featureFlags\": {\"transient-504-flag\": true}}",
            "status_code": 200
          }
        ]
      }
      """
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "transient-504-flag"
      }
      """
    And exactly 2 requests containing /flags should have been received
    And the public flag getter should return JSON true

  Scenario: Remote flag lookup captures a feature-flag-called event
    When the mock serves these ordered flag responses:
      """application/json
      {
        "responses": [
          {
            "body": "{\"featureFlags\": {\"my-flag\": true}}",
            "status_code": 200
          }
        ]
      }
      """
    And the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "my-flag"
      }
      """
    And pending captures are flushed
    And exactly 1 received events should be named "$feature_flag_called"
    And a received event named "$feature_flag_called" should have property "$feature_flag" equal to JSON "my-flag"
    And a received event named "$feature_flag_called" should have property "$feature_flag_response" equal to JSON true
