@migration @yaml_parity_v1 @both @requires:feature_flags_local_evaluation_v1
Feature: Native local equality across definitions reloads
  Typed service definitions flow through authenticated HTTP and the native loader.
  Each public getter is conclusively local; initialization and reloads never evaluate remotely.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  @case:migration:yaml-parity-v1:feature_flags_local_evaluation:matching_version_missing
  Scenario: matching_version_missing
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}}
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {
        "project_token": "phc_test_key",
        "config": {
          "secret_key": "phx_test_key"
        }
      }
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    Then exactly 0 requests containing /flags should have been received
    And no remote flag evaluation path should have been requested

  @case:migration:yaml-parity-v1:feature_flags_local_evaluation:matching_version_1
  Scenario: matching_version_1
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 1
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {
        "project_token": "phc_test_key",
        "config": {
          "secret_key": "phx_test_key"
        }
      }
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    Then exactly 0 requests containing /flags should have been received
    And no remote flag evaluation path should have been requested

  @case:migration:yaml-parity-v1:feature_flags_local_evaluation:matching_version_2
  Scenario: matching_version_2
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 2
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {
        "project_token": "phc_test_key",
        "config": {
          "secret_key": "phx_test_key"
        }
      }
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "true"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "boolean_array_pro_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_true_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": []
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "true_property_array_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_uppercase_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "FALSE"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_null_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": null
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_truthy_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              "TRUE",
              []
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_nested_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": [
            true,
            [
              false
            ]
          ]
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_false_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": false
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_zero_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": 0
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "empty_banana_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "mixed_members_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "string_normalization_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "pro"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "member_boolean_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": true
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "group_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "groups": {
          "company": "acme"
        },
        "group_properties": {
          "company": {
            "value": "banana"
          }
        }
      }
      """
    Then the local flag getter should return JSON true
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "cohort_is_not",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    Then exactly 0 requests containing /flags should have been received
    And no remote flag evaluation path should have been requested

  @case:migration:yaml-parity-v1:feature_flags_local_evaluation:version_only_reload_1_2_1_2_missing
  Scenario: version_only_reload_1_2_1_2_missing
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 1
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {
        "project_token": "phc_test_key",
        "config": {
          "secret_key": "phx_test_key"
        }
      }
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 2
      }}
      """
    When local definitions are publicly reloaded within 5000 milliseconds
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 1
      }}
      """
    When local definitions are publicly reloaded within 5000 milliseconds
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}},
        "property_matching_version": 2
      }}
      """
    When local definitions are publicly reloaded within 5000 milliseconds
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON false
    And the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id": 1, "name": "false_banana_exact", "key": "false_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 2, "name": "false_banana_is_not", "key": "false_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 3, "name": "false_zero_exact", "key": "false_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 4, "name": "false_zero_is_not", "key": "false_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 5, "name": "boolean_array_true_exact", "key": "boolean_array_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 6, "name": "boolean_array_true_is_not", "key": "boolean_array_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 7, "name": "boolean_array_pro_exact", "key": "boolean_array_pro_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 8, "name": "boolean_array_pro_is_not", "key": "boolean_array_pro_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["true", "false"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 9, "name": "empty_true_exact", "key": "empty_true_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 10, "name": "empty_true_is_not", "key": "empty_true_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 11, "name": "empty_array_exact", "key": "empty_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 12, "name": "empty_array_is_not", "key": "empty_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 13, "name": "true_property_array_exact", "key": "true_property_array_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 14, "name": "true_property_array_is_not", "key": "true_property_array_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": true, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 15, "name": "false_uppercase_exact", "key": "false_uppercase_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 16, "name": "false_uppercase_is_not", "key": "false_uppercase_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 17, "name": "false_null_exact", "key": "false_null_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 18, "name": "false_null_is_not", "key": "false_null_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 19, "name": "empty_nested_truthy_exact", "key": "empty_nested_truthy_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 20, "name": "empty_nested_truthy_is_not", "key": "empty_nested_truthy_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 21, "name": "empty_nested_false_exact", "key": "empty_nested_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 22, "name": "empty_nested_false_is_not", "key": "empty_nested_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 23, "name": "empty_false_exact", "key": "empty_false_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 24, "name": "empty_false_is_not", "key": "empty_false_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 25, "name": "empty_zero_exact", "key": "empty_zero_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 26, "name": "empty_zero_is_not", "key": "empty_zero_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 27, "name": "empty_banana_exact", "key": "empty_banana_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 28, "name": "empty_banana_is_not", "key": "empty_banana_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 29, "name": "mixed_members_exact", "key": "mixed_members_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 30, "name": "mixed_members_is_not", "key": "mixed_members_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": [false, "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 31, "name": "string_normalization_exact", "key": "string_normalization_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 32, "name": "string_normalization_is_not", "key": "string_normalization_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["FREE", "PRO"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 33, "name": "member_boolean_exact", "key": "member_boolean_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "exact", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 34, "name": "member_boolean_is_not", "key": "member_boolean_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": ["TrUe", "FALSE"], "operator": "is_not", "type": "person"}], "rollout_percentage": 100}]}},
          {"id": 35, "name": "group_exact", "key": "group_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "exact", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 36, "name": "cohort_exact", "key": "cohort_exact", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 1, "type": "cohort"}], "rollout_percentage": 100}]}},
          {"id": 37, "name": "group_is_not", "key": "group_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "value", "value": false, "operator": "is_not", "type": "group"}], "rollout_percentage": 100}], "aggregation_group_type_index": 0}},
          {"id": 38, "name": "cohort_is_not", "key": "cohort_is_not", "active": true, "version": 2, "filters": {"groups": [{"properties": [{"key": "id", "value": 3, "type": "cohort"}], "rollout_percentage": 100}]}}
        ],
        "group_type_mapping": {"0": "company"},
        "cohorts": {"1": {"type": "AND", "values": [{"key": "id", "value": 2, "type": "cohort"}]}, "2": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "exact", "type": "person"}]}, "3": {"type": "AND", "values": [{"key": "id", "value": 4, "type": "cohort"}]}, "4": {"type": "OR", "values": [{"key": "value", "value": false, "operator": "is_not", "type": "person"}]}}
      }}
      """
    When local definitions are publicly reloaded within 5000 milliseconds
    And the local flag getter is called with JSON arguments:
      """application/json
      {
        "key": "false_banana_exact",
        "distinct_id": "local-user",
        "only_evaluate_locally": true,
        "person_properties": {
          "value": "banana"
        }
      }
      """
    Then the local flag getter should return JSON true
    Then exactly 0 requests containing /flags should have been received
    And no remote flag evaluation path should have been requested
