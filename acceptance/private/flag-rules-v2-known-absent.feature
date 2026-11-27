@private @canonical_behavior @acceptance @flag_rules_v2_local_evaluation @server @requires:feature_flags_local_evaluation_v2 @requires:feature_flags_known_absent_v1
Feature: Known-absent property keys in local evaluation of config version 2 flags
  The case of flag-rules-v2-local-evaluation.feature that also needs an SDK that accepts
  known-absent property keys. It is a feature of its own so that each of the two features
  is opted into the server suite as a whole, once SDKs implement what it requires.

  # The steps are those of flag-rules-v2-local-evaluation.feature; its header describes
  # the ones that posthog-sdk-test-harness#123 binds.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  Scenario: A key listed as known absent falls back with the listing
    Read with the supplied value true, the rule would miss and the flag would be false
    locally. The flags service reads "opted_out" as absent, and the rule matches.

    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions":{"flags":[{"id":407,"key":"beta-opt-in","active":true,"version":1,"filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"opted_out","type":"person","operator":"is_not_set","value":null,"negation":false}]},"value":true}]}}],"group_type_mapping":{},"cohorts":{}}}
      """
    And the mock serves this /flags response body:
      """application/json
      {"errorsWhileComputingFlags":false,"flags":{"beta-opt-in":{"key":"beta-opt-in","value":true,"reason":{"code":"targeting_match","condition_index":0},"metadata":{"id":407,"version":1,"config_version":2,"has_experiment":false,"payload":null,"rule_type":"targeted_release","rule_id":"11111111-1111-4111-8111-111111111111"}}},"requestId":"20000000-0000-4000-8000-000000000005","evaluatedAt":1800000000000}
      """
    And the SDK is initialized for native local evaluation with remote fallback and JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When get feature flag is called with JSON arguments:
      """application/json
      {"key":"beta-opt-in","distinct_id":"person-example","person_properties":{"opted_out":true},"person_property_keys_known_absent":["opted_out"]}
      """
    Then the public flag getter should return exactly JSON true
    And exactly 1 requests containing /flags should have been received
    And the first flags request field "person_property_keys_known_absent" should equal JSON ["opted_out"]
