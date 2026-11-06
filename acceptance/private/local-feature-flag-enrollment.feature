@private @canonical_behavior @acceptance @local_feature_flag_evaluator @server
Feature: Local feature flag enrollment
  Downloaded definitions use the flags service's person-level enrollment rule.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  @case:<case_id>
  Scenario Outline: Enrollment values and ordering agree with the flags service
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":<active>,"filters":{"feature_enrollment":<marker>,"holdout":<holdout>,"groups":[{"properties":[],"rollout_percentage":<rollout>}]}}]}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"beta-feature","distinct_id":"user-123","only_evaluate_locally":true,"person_properties":<properties>}
      """
    Then the local flag getter should return JSON <expected>
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id            | active | marker | holdout                               | rollout | properties                                    | expected |
      | enrolled-boolean   | true   | true   | null                                  | 0       | {"$feature_enrollment/beta-feature":true}      | true     |
      | enrolled-string    | true   | true   | null                                  | 0       | {"$feature_enrollment/beta-feature":"true"}    | true     |
      | opted-out-boolean  | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":false}     | false    |
      | opted-out-string   | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":"false"}   | false    |
      | numeric-one        | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":1}         | false    |
      | numeric-zero       | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":0}         | false    |
      | explicit-null      | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":null}      | false    |
      | uppercase-string   | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":"True"}    | false    |
      | empty-string       | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":""}        | false    |
      | empty-array        | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":[]}        | false    |
      | empty-object       | true   | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":{}}        | false    |
      | enrolled-holdout   | true   | true   | {"id":727,"exclusion_percentage":100} | 0       | {"$feature_enrollment/beta-feature":true}      | true     |
      | opted-out-holdout  | true   | true   | {"id":727,"exclusion_percentage":100} | 100     | {"$feature_enrollment/beta-feature":false}     | false    |
      | inactive-flag      | false  | true   | null                                  | 100     | {"$feature_enrollment/beta-feature":true}      | false    |
      | inactive-missing   | false  | true   | null                                  | 100     | {}                                            | false    |
      | disabled-marker   | true   | false  | null                                  | 100     | {}                                            | true     |
      | null-marker       | true   | null   | null                                  | 100     | {}                                            | true     |

  Scenario: An absent enrollment marker preserves ordinary targeting
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"groups":[{"properties":[],"rollout_percentage":100}]}}]}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"beta-feature","distinct_id":"user-123","only_evaluate_locally":true}
      """
    Then the local flag getter should return JSON true
    And no remote flag evaluation path should have been requested

  @case:<case_id>
  Scenario Outline: A bulk snapshot and a dependent flag use enrollment
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"feature_enrollment":true,"groups":[{"properties":[],"rollout_percentage":<rollout>}]}},{"id":2,"key":"dependent","active":true,"filters":{"groups":[{"properties":[{"key":"beta-feature","type":"flag","operator":"flag_evaluates_to","value":true,"dependency_chain":["beta-feature"]}],"rollout_percentage":100}]}}]}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"user-123","options":{"only_evaluate_locally":true,"person_properties":{"$feature_enrollment/beta-feature":<enrolled>}},"reads":[{"method":"get_flag","key":"beta-feature"},{"method":"get_flag","key":"dependent"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":<enrolled>},{"value":<enrolled>}]}
      """
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id            | enrolled | rollout |
      | bulk-enrolled      | true     | 0       |
      | bulk-opted-out     | false    | 100     |

  Scenario: A local-only snapshot leaves missing enrollment and its dependency unresolved
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"feature_enrollment":true,"groups":[{"properties":[],"rollout_percentage":100}]}},{"id":2,"key":"dependent","active":true,"filters":{"groups":[{"properties":[{"key":"beta-feature","type":"flag","operator":"flag_evaluates_to","value":true,"dependency_chain":["beta-feature"]}],"rollout_percentage":100}]}},{"id":3,"key":"control","active":true,"filters":{"groups":[{"properties":[],"rollout_percentage":100}]}}]}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"user-123","options":{"only_evaluate_locally":true},"reads":[{"method":"keys"},{"method":"get_flag","key":"control"},{"method":"get_flag","key":"beta-feature"},{"method":"get_flag","key":"dependent"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":["control"]},{"value":true},{"missing":true},{"missing":true}]}
      """
    And no remote flag evaluation path should have been requested

  Scenario: Missing enrollment falls back even when local targeting matches
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"feature_enrollment":true,"groups":[{"properties":[],"rollout_percentage":100}]}}]}}
      """
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"user-123":{"beta-feature":{"value":false}}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When get feature flag is called with JSON arguments:
      """application/json
      {"key":"beta-feature","distinct_id":"user-123"}
      """
    Then the public flag getter should return JSON false
    And exactly 1 requests containing /flags should have been received

  @case:<case_id>
  Scenario Outline: Enrollment and continuity bypass unsupported release conditions
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"flags":[{"id":1,"key":"beta-feature","active":true,"ensure_experience_continuity":<continuity>,"filters":{"feature_enrollment":true,"groups":[{"properties":[{"key":"id","type":"cohort","operator":"in","value":123}],"rollout_percentage":100}]}},{"id":2,"key":"control","active":true,"filters":{"groups":[{"properties":[],"rollout_percentage":100}]}}]}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"user-123","options":{"only_evaluate_locally":true,"person_properties":<properties>},"reads":[{"method":"get_flag","key":"control"},{"method":"get_flag","key":"beta-feature"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":true},<outcome>]}
      """
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id             | continuity | properties                                 | outcome          |
      | continuity-missing  | true       | {}                                         | {"missing":true} |
      | continuity-enrolled | true       | {"$feature_enrollment/beta-feature":true}  | {"missing":true} |
      | continuity-opt-out  | true       | {"$feature_enrollment/beta-feature":false} | {"missing":true} |
      | cohort-enrolled     | false      | {"$feature_enrollment/beta-feature":true}  | {"value":true}   |
      | cohort-opt-out      | false      | {"$feature_enrollment/beta-feature":false} | {"value":false}  |
      | cohort-missing      | false      | {}                                         | {"missing":true} |

  Scenario: Person enrollment remains effective without group context
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"group_type_mapping":{"0":"company"},"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"aggregation_group_type_index":0,"feature_enrollment":true,"groups":[{"properties":[],"rollout_percentage":0}]}}]}}
      """
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"user-123":{"beta-feature":{"value":true}}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When get feature flag is called with JSON arguments:
      """application/json
      {"key":"beta-feature","distinct_id":"user-123","person_properties":{"$feature_enrollment/beta-feature":true}}
      """
    Then the public flag getter should return JSON true

  Scenario: A group definition cannot turn a person's opt-out into enrollment
    Given the definitions service serves this typed document:
      """application/json
      {"definitions":{"group_type_mapping":{"0":"company"},"flags":[{"id":1,"key":"beta-feature","active":true,"filters":{"aggregation_group_type_index":0,"feature_enrollment":true,"groups":[{"properties":[],"rollout_percentage":100}]}}]}}
      """
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"user-123":{"beta-feature":{"value":false}}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When get feature flag is called with JSON arguments:
      """application/json
      {"key":"beta-feature","distinct_id":"user-123","groups":{"company":"acme"},"person_properties":{"$feature_enrollment/beta-feature":false},"group_properties":{"company":{"$feature_enrollment/beta-feature":true}}}
      """
    Then the public flag getter should return JSON false
