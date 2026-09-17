@migration @yaml_parity_v1 @server @requires:flags_v2 @sdk:server
Feature: Native server remote flag getters
  Ordinary native server calls against the flags v2 wire API.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset
    And the server uses its native flag startup and getter behavior with no installed local definitions or results

  @case:migration:yaml-parity-v1:feature_flags:request_with_person_properties_device_id
  Scenario: request_with_person_properties_device_id
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

  @case:migration:yaml-parity-v1:feature_flags:flags_request_uses_v2_query_param
  Scenario: flags_request_uses_v2_query_param
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

  @case:migration:yaml-parity-v1:feature_flags:flags_request_hits_flags_path_not_decide
  Scenario: flags_request_hits_flags_path_not_decide
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

  @case:migration:yaml-parity-v1:feature_flags:flags_request_omits_authorization_header
  Scenario: flags_request_omits_authorization_header
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

  @case:migration:yaml-parity-v1:feature_flags:token_in_flags_body_matches_init
  Scenario: token_in_flags_body_matches_init
    When the SDK is initialized with token "phc_specific_key_12345" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "token" should equal JSON "phc_specific_key_12345"

  @case:migration:yaml-parity-v1:feature_flags:groups_round_trip
  Scenario: groups_round_trip
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

  @case:migration:yaml-parity-v1:feature_flags:groups_default_to_empty_object
  Scenario: groups_default_to_empty_object
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

  @case:migration:yaml-parity-v1:feature_flags:disable_geoip_false_propagates_as_geoip_disable_false
  Scenario: disable_geoip_false_propagates_as_geoip_disable_false
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

  @case:migration:yaml-parity-v1:feature_flags:disable_geoip_omitted_defaults_to_false
  Scenario: disable_geoip_omitted_defaults_to_false
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "any-flag"
      }
      """
    And the first flags request field "geoip_disable" should equal JSON false

  @case:migration:yaml-parity-v1:feature_flags:flag_keys_to_evaluate_contains_only_requested_key
  Scenario: flag_keys_to_evaluate_contains_only_requested_key
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And get feature flag is called with JSON arguments:
      """application/json
      {
        "distinct_id": "user_1",
        "key": "my-specific-flag"
      }
      """
    And the first flags request field "flag_keys_to_evaluate" should equal JSON ["my-specific-flag"]

  @case:migration:yaml-parity-v1:feature_flags:no_flags_request_on_init_alone
  Scenario: no_flags_request_on_init_alone
    When the SDK is initialized with token "phc_test_key" and no additional configuration
    And exactly 0 requests containing /flags should have been received

  @case:migration:yaml-parity-v1:feature_flags:no_flags_request_on_normal_capture
  Scenario: no_flags_request_on_normal_capture
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

  @case:migration:yaml-parity-v1:feature_flags:two_flag_calls_produce_two_remote_requests @requires:flags_getter_remote_uncached
  Scenario: two_flag_calls_produce_two_remote_requests
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

  @case:migration:yaml-parity-v1:feature_flags:mock_response_value_is_returned_to_caller
  Scenario: mock_response_value_is_returned_to_caller
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

  @case:migration:yaml-parity-v1:feature_flags:retries_flags_on_502
  Scenario: retries_flags_on_502
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

  @case:migration:yaml-parity-v1:feature_flags:retries_flags_on_504
  Scenario: retries_flags_on_504
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

  @case:migration:yaml-parity-v1:feature_flags:get_feature_flag_captures_feature_flag_called_event
  Scenario: get_feature_flag_captures_feature_flag_called_event
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
