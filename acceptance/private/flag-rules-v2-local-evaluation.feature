@private @canonical_behavior @acceptance @flag_rules_v2_local_evaluation @server @requires:feature_flags_local_evaluation_v2
Feature: Local evaluation of config version 2 flags
  A server SDK that evaluates config version 2 flags requests the definitions feed
  with v=2 and evaluates those flags itself. An entry that it cannot evaluate falls
  back to /flags in auto mode and has no value in local-only mode. An inactive flag is
  off. Local results send the config version 2 events with locally_evaluated true.

  # The mixed feed is fixtures/wire/definitions_feed.json of the rules v2 contract
  # (contract 10.1.0, posthog-sdk-test-harness 1.36.0), read with its context: distinct id
  # "person-example" and person properties {"plan": "pro"}. The "example-display-key"
  # documents come from corpus/v2_local_evaluation.json of the same contract.
  #
  # Four steps need harness bindings that the local evaluation suite adds:
  # - "the definitions service serves this typed document for v=2 requests:" serves its
  #   document to a definitions request with exactly one v parameter, equal to 2. Every
  #   other definitions request gets the document of "the definitions service serves
  #   this typed document:", and so does a v=2 request when no v=2 document is set, as
  #   the flags service does for a project without config version 2 flags.
  # - "the SDK is initialized for native local evaluation with remote fallback and JSON
  #   arguments:" initializes the SDK as "the SDK is initialized for native local
  #   evaluation with JSON arguments:" does, but allows /flags requests. The native step
  #   fails a scenario that sends any /flags request, so each Rule below, which holds a
  #   fallback scenario, uses this step, and its scenarios assert /flags traffic
  #   themselves.
  # - "every flag definitions request query parameter "v" should equal "2"".
  # - "no received event named "<name>" should have property "<property>"".

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # The definitions request

  Scenario: The SDK requests the version 2 feed on the first load and on a reload
    The legacy document lacks "layout-preview", so an SDK that did not send v=2 would
    have to ask /flags for it.

    Given the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id":301,"name":"Banner for every person","key":"legacy-banner","filters":{"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false}
        ],
        "group_type_mapping": {},
        "cohorts": {}
      }}
      """
    And the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions": {
        "flags": [
          {"id":301,"name":"Banner for every person","key":"legacy-banner","filters":{"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":302,"name":"Layout preview for paying plans","key":"layout-preview","filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro"],"negation":false,"label":"Plan"}]},"description":"Preview for paying plans.","metadata":{"display_color":"blue"},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":7,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":303,"name":"Unknown config version","key":"future-config-version","filters":{"version":3,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":2,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":304,"name":"Retired banner","key":"legacy-retired-banner","filters":{"version":1,"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":false,"ensure_experience_continuity":false,"version":9,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":305,"name":"Checkout button copy","key":"checkout-copy","filters":{"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["enterprise"],"negation":false}]},"value":"priority"},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"percentage_rollout","targeting":{"properties":[]},"value":"short","rollout_percentage":100,"on_rollout_miss":"return_default","assignment_algorithm":"sha1_60_v1","seed":"checkout-copy-rollout","assign_by":"person"}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":3,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":306,"name":"Unknown rule type after a rule that matches","key":"future-rule-type","filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"scheduled_release","targeting":{"properties":[]},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":1,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":307,"name":"Beta for team workspaces","key":"legacy-workspace-beta","filters":{"aggregation_group_type_index":0,"groups":[{"properties":[{"key":"tier","type":"group","group_type_index":0,"operator":"exact","value":["team"]}],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":2,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":308,"name":"Results per page test","key":"results-per-page","filters":{"version":2,"return_type":"number","default_value":10,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"experiment","targeting":{"properties":[]},"paused":false,"rollout_percentage":100,"on_rollout_miss":"continue","assignment_algorithm":"sha1_60_v1","seed":"results-per-page-test","assign_by":"person","variants":[{"key":"control","weight":50,"value":20},{"key":"test","weight":50,"value":50}]}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":5,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":true},
          {"id":309,"name":"Unknown rule field after a rule that matches","key":"future-rule-field","filters":{"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":"compact"},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"percentage_rollout","targeting":{"properties":[]},"value":"short","rollout_percentage":100,"on_rollout_miss":"return_default","assignment_algorithm":"sha1_60_v1","seed":"future-rule-field-rollout","assign_by":"person","schedule":{"starts_at":"2030-01-01"}}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":1,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":310,"name":"Offer for the paying cohort","key":"legacy-cohort-offer","filters":{"groups":[{"properties":[{"key":"id","type":"cohort","value":41}],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":6,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":311,"name":"Search ranking model","key":"search-ranking","filters":{"version":2,"return_type":"object","default_value":{"model":"baseline"},"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro","enterprise"],"negation":false}]},"value":{"model":"semantic","boost":1.5}}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":8,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":312,"name":"Seasonal theme","key":"seasonal-theme","filters":{"version":2,"return_type":"string","default_value":"plain","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":"winter"}]},"deleted":false,"active":false,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false}
        ],
        "group_type_mapping": {"0":"workspace"},
        "cohorts": {"41":{"type":"OR","values":[{"type":"AND","values":[{"key":"plan","type":"person","operator":"exact","value":["pro"]}]}]}},
        "minimal_flag_called_events": false,
        "property_matching_version": 2
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"layout-preview","distinct_id":"person-example","person_properties":{"plan":"pro"}}
      """
    Then the local flag getter should return JSON true
    When local definitions are publicly reloaded within 5000 milliseconds
    And the local flag getter is called with JSON arguments:
      """application/json
      {"key":"layout-preview","distinct_id":"person-example","person_properties":{"plan":"pro"}}
      """
    Then the local flag getter should return JSON true
    And every flag definitions request query parameter "v" should equal "2"
    And no remote flag evaluation path should have been requested

  Scenario: Without config version 2 flags the version 2 feed is the legacy body
    Given the definitions service serves this typed document:
      """application/json
      {"definitions": {
        "flags": [
          {"id":301,"name":"Banner for every person","key":"legacy-banner","filters":{"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":304,"name":"Retired banner","key":"legacy-retired-banner","filters":{"version":1,"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":false,"ensure_experience_continuity":false,"version":9,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false}
        ],
        "group_type_mapping": {},
        "cohorts": {}
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"legacy-banner","distinct_id":"person-example","person_properties":{"plan":"pro"}}
      """
    Then the local flag getter should return JSON true
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"legacy-retired-banner","distinct_id":"person-example","person_properties":{"plan":"pro"}}
      """
    Then the local flag getter should return JSON false
    And every flag definitions request query parameter "v" should equal "2"
    And no remote flag evaluation path should have been requested

  # Inactive flags: corpus/v2_local_evaluation.json, family "flag_disabled"

  @case:<case_id>
  Scenario Outline: An inactive flag is off whatever its document says
    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions":{"flags":[{"id":402,"key":"example-display-key","active":false,"version":1,"filters":<config>}],"group_type_mapping":{},"cohorts":{}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"example-display-key","distinct_id":"person-example","person_properties":{"plan":"pro"}}
      """
    Then the local flag getter should return JSON false
    And no remote flag evaluation path should have been requested

    Examples: The contract's flag_disabled cases
      | case_id                         | config                                                                                                                                                                                                                                                                                                                                                                                                                                         |
      | inactive-boolean                | {"version":2,"return_type":"boolean","default_value":true,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true}]}                                                                                                                                                                                                                                                   |
      | inactive-string                 | {"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":"compact"}]}                                                                                                                                                                                                                                         |
      | inactive-number                 | {"version":2,"return_type":"number","default_value":20,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":50}]}                                                                                                                                                                                                                                                        |
      | inactive-object                 | {"version":2,"return_type":"object","default_value":{"columns":2},"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":{"columns":3,"dense":true}}]}                                                                                                                                                                                                                     |
      | inactive-experiment             | {"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"experiment","targeting":{"properties":[]},"paused":false,"rollout_percentage":100,"on_rollout_miss":"continue","assignment_algorithm":"sha1_60_v1","seed":"example-split","assign_by":"person","variants":[{"key":"control","weight":50,"value":"standard"},{"key":"test","weight":50,"value":"compact"}]}]} |
      | inactive-before-missing-context | {"version":2,"return_type":"boolean","default_value":true,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"color","type":"person","operator":"exact","value":["blue"],"negation":false}]},"value":true}]}                                                                                                                                                               |

    Examples: An unsupported document, which the contract does not pin yet
      | case_id                       | config                                                                                                                                                                                        |
      | inactive-unsupported-document | {"version":2,"return_type":"boolean","default_value":true,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"scheduled_release","targeting":{"properties":[]},"value":true}]} |

  # Dates

  @case:<case_id>
  Scenario Outline: A filter date without an offset is midnight UTC
    The filter "2024-06-15" is 2024-06-15T00:00:00Z. Read in the host's timezone
    instead, the result changes on a host east or west of UTC.

    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions": {
        "flags": [
          {"id":403,"key":"launch-window","active":true,"version":1,"filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"44444444-4444-4444-8444-444444444444","rule_type":"targeted_release","targeting":{"properties":[{"key":"signed_up_at","type":"person","operator":"is_date_before","value":"2024-06-15","negation":false}]},"value":true}]}}
        ],
        "group_type_mapping": {},
        "cohorts": {}
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"launch-window","distinct_id":"person-example","person_properties":{"signed_up_at":"<signed_up_at>"}}
      """
    Then the local flag getter should return JSON <result>
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id          | signed_up_at              | result |
      | date-east-of-utc | 2024-06-15T00:30:00+02:00 | true   |
      | date-west-of-utc | 2024-06-14T23:30:00-02:00 | false  |

  # Exact matching: corpus cases v2_boolean.property.exact_false and
  # v2_boolean.property.legacy_exact_setting

  @case:<case_id>
  Scenario Outline: Exact matching follows the snapshot's property matching version
    The rule compares "color" with false, and the caller supplies 0. Legacy matching
    matches, and explicit matching does not.

    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions":{<matching_version>"flags":[{"id":405,"key":"example-display-key","active":true,"version":1,"filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"color","type":"person","operator":"exact","value":false,"negation":false}]},"value":true}]}}],"group_type_mapping":{},"cohorts":{}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When the local flag getter is called with JSON arguments:
      """application/json
      {"key":"example-display-key","distinct_id":"person-example","person_properties":{"color":0}}
      """
    Then the local flag getter should return JSON <result>
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id                  | matching_version               | result |
      | matching-version-omitted |                                | true   |
      | matching-version-1       | "property_matching_version":1, | true   |
      | matching-version-2       | "property_matching_version":2, | false  |

  # Targeting that the contract does not cover yet

  @case:<case_id>
  Scenario Outline: Group, cohort and flag targeting make the whole flag unsupported
    Each document is valid under the contract's config schema. Its first rule targets
    everyone, and the read supplies the group and cohort context, so an SDK that
    evaluated what it reads would return true.

    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions":{"flags":[{"id":406,"key":"example-display-key","active":true,"version":1,"filters":<config>}],"group_type_mapping":{"0":"workspace"},"cohorts":{"41":{"type":"OR","values":[{"type":"AND","values":[{"key":"plan","type":"person","operator":"exact","value":["pro"]}]}]}}}}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"person-example","options":{"only_evaluate_locally":true,"groups":{"workspace":"workspace-example"},"person_properties":{"plan":"pro"},"group_properties":{"workspace":{"tier":"team"}}},"reads":[{"method":"get_flag","key":"example-display-key"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"missing":true}]}
      """
    And no remote flag evaluation path should have been requested

    Examples:
      | case_id                      | config                                                                                                                                                                                                                                                                                                                                                                                                                       |
      | unsupported-aggregation      | {"version":2,"return_type":"boolean","default_value":false,"aggregation_group_type_index":0,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true}]}                                                                                                                                                                                               |
      | unsupported-group-predicate  | {"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"targeted_release","targeting":{"properties":[{"key":"tier","type":"group","group_type_index":0,"operator":"exact","value":["team"],"negation":false}]},"value":true}]} |
      | unsupported-cohort-predicate | {"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"targeted_release","targeting":{"properties":[{"key":"id","type":"cohort","operator":"in","value":41,"negation":false}]},"value":true}]}                                |
      | unsupported-flag-predicate   | {"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"targeted_release","targeting":{"properties":[{"key":"layout-preview","type":"flag","operator":"flag_evaluates_to","value":true,"negation":false}]},"value":true}]}     |

  # Dependencies

  Scenario: A config version 1 flag that depends on a config version 2 flag is not evaluated locally
    The flags service never sends this pair. The SDK treats the dependency as one that
    it cannot resolve.

    Given the definitions service serves this typed document for v=2 requests:
      """application/json
      {"definitions": {
        "flags": [
          {"id":302,"name":"Layout preview for paying plans","key":"layout-preview","filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro"],"negation":false,"label":"Plan"}]},"description":"Preview for paying plans.","metadata":{"display_color":"blue"},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":7,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
          {"id":404,"key":"legacy-dependent","active":true,"version":1,"filters":{"groups":[{"properties":[{"key":"layout-preview","type":"flag","operator":"flag_evaluates_to","value":true,"dependency_chain":["layout-preview"]}],"rollout_percentage":100}]}}
        ],
        "group_type_mapping": {},
        "cohorts": {}
      }}
      """
    And the SDK is initialized for native local evaluation with JSON arguments:
      """application/json
      {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"person-example","options":{"only_evaluate_locally":true,"person_properties":{"plan":"pro"}},"reads":[{"method":"get_flag","key":"legacy-dependent"},{"method":"get_flag","key":"layout-preview"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"missing":true},{"value":true}]}
      """
    And no remote flag evaluation path should have been requested

  Rule: Ordered rules stop at a missing property

    The flag is corpus/v2_local_evaluation.json, family "context": "plan" is "pro"
    returns "first", "color" is "blue" returns "second", and everyone gets "third".

    Background:
      Given the definitions service serves this typed document for v=2 requests:
        """application/json
        {"definitions": {
          "flags": [
            {"id":401,"key":"example-display-key","active":true,"version":1,"filters":{"version":2,"return_type":"string","default_value":"default","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro"],"negation":false}]},"value":"first"},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"targeted_release","targeting":{"properties":[{"key":"color","type":"person","operator":"exact","value":["blue"],"negation":false}]},"value":"second"},{"id":"33333333-3333-4333-8333-333333333333","rule_type":"targeted_release","targeting":{"properties":[]},"value":"third"}]}}
          ],
          "group_type_mapping": {},
          "cohorts": {}
        }}
        """
      And the SDK is initialized for native local evaluation with remote fallback and JSON arguments:
        """application/json
        {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
        """

    Scenario: A rule that matches before a missing property decides the flag
      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"example-display-key","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      Then the local flag getter should return JSON "first"
      And no remote flag evaluation path should have been requested

    Scenario: A missing property ends the evaluation, and the SDK asks /flags
      The first rule misses, and the second needs "color", which the caller did not
      supply. An evaluator that skipped the second rule would return "third" locally.

      Given the mock serves this /flags response body:
        """application/json
        {
          "errorsWhileComputingFlags": false,
          "flags": {
            "example-display-key": {"key":"example-display-key","value":"second","reason":{"code":"targeting_match","condition_index":1},"metadata":{"id":401,"version":1,"config_version":2,"has_experiment":false,"payload":null,"rule_type":"targeted_release","rule_id":"22222222-2222-4222-8222-222222222222"}}
          },
          "requestId": "20000000-0000-4000-8000-000000000004",
          "evaluatedAt": 1800000000000
        }
        """
      When get feature flag is called with JSON arguments:
        """application/json
        {"key":"example-display-key","distinct_id":"person-example","person_properties":{"plan":"free"}}
        """
      Then the public flag getter should return exactly JSON "second"
      And exactly 1 requests containing /flags should have been received
      When pending captures are flushed
      Then exactly 1 received events should be named "$feature_flag_called"
      And a received event named "$feature_flag_called" should have property "locally_evaluated" equal to JSON false
      And a received event named "$feature_flag_called" should have property "$feature_flag_rule_id" equal to JSON "22222222-2222-4222-8222-222222222222"

    Scenario: In local-only mode a missing property leaves the flag without a value
      When evaluate flags and read is called with JSON arguments:
        """application/json
        {"distinct_id":"person-example","options":{"only_evaluate_locally":true,"person_properties":{"plan":"free"}},"reads":[{"method":"get_flag","key":"example-display-key"}]}
        """
      Then the public snapshot outcomes should have these semantics:
        """application/json
        {"results":[{"missing":true}]}
        """
      And no remote flag evaluation path should have been requested

  Rule: The contract's mixed feed

    Every scenario reads the feed of fixtures/wire/definitions_feed.json for distinct id
    "person-example" with person properties {"plan": "pro"}.

    Background:
      Given the definitions service serves this typed document for v=2 requests:
        """application/json
        {"definitions": {
          "flags": [
            {"id":301,"name":"Banner for every person","key":"legacy-banner","filters":{"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":302,"name":"Layout preview for paying plans","key":"layout-preview","filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro"],"negation":false,"label":"Plan"}]},"description":"Preview for paying plans.","metadata":{"display_color":"blue"},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":7,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":303,"name":"Unknown config version","key":"future-config-version","filters":{"version":3,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":2,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":304,"name":"Retired banner","key":"legacy-retired-banner","filters":{"version":1,"groups":[{"properties":[],"rollout_percentage":100}]},"deleted":false,"active":false,"ensure_experience_continuity":false,"version":9,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":305,"name":"Checkout button copy","key":"checkout-copy","filters":{"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["enterprise"],"negation":false}]},"value":"priority"},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"percentage_rollout","targeting":{"properties":[]},"value":"short","rollout_percentage":100,"on_rollout_miss":"return_default","assignment_algorithm":"sha1_60_v1","seed":"checkout-copy-rollout","assign_by":"person"}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":3,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":306,"name":"Unknown rule type after a rule that matches","key":"future-rule-type","filters":{"version":2,"return_type":"boolean","default_value":false,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":true},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"scheduled_release","targeting":{"properties":[]},"value":true}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":1,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":307,"name":"Beta for team workspaces","key":"legacy-workspace-beta","filters":{"aggregation_group_type_index":0,"groups":[{"properties":[{"key":"tier","type":"group","group_type_index":0,"operator":"exact","value":["team"]}],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":2,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":308,"name":"Results per page test","key":"results-per-page","filters":{"version":2,"return_type":"number","default_value":10,"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"experiment","targeting":{"properties":[]},"paused":false,"rollout_percentage":100,"on_rollout_miss":"continue","assignment_algorithm":"sha1_60_v1","seed":"results-per-page-test","assign_by":"person","variants":[{"key":"control","weight":50,"value":20},{"key":"test","weight":50,"value":50}]}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":5,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":true},
            {"id":309,"name":"Unknown rule field after a rule that matches","key":"future-rule-field","filters":{"version":2,"return_type":"string","default_value":"standard","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":"compact"},{"id":"22222222-2222-4222-8222-222222222222","rule_type":"percentage_rollout","targeting":{"properties":[]},"value":"short","rollout_percentage":100,"on_rollout_miss":"return_default","assignment_algorithm":"sha1_60_v1","seed":"future-rule-field-rollout","assign_by":"person","schedule":{"starts_at":"2030-01-01"}}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":1,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":310,"name":"Offer for the paying cohort","key":"legacy-cohort-offer","filters":{"groups":[{"properties":[{"key":"id","type":"cohort","value":41}],"rollout_percentage":100}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":6,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":311,"name":"Search ranking model","key":"search-ranking","filters":{"version":2,"return_type":"object","default_value":{"model":"baseline"},"rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[{"key":"plan","type":"person","operator":"exact","value":["pro","enterprise"],"negation":false}]},"value":{"model":"semantic","boost":1.5}}]},"deleted":false,"active":true,"ensure_experience_continuity":false,"version":8,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false},
            {"id":312,"name":"Seasonal theme","key":"seasonal-theme","filters":{"version":2,"return_type":"string","default_value":"plain","rules":[{"id":"11111111-1111-4111-8111-111111111111","rule_type":"targeted_release","targeting":{"properties":[]},"value":"winter"}]},"deleted":false,"active":false,"ensure_experience_continuity":false,"version":4,"evaluation_runtime":"all","bucketing_identifier":"distinct_id","evaluation_contexts":[],"has_experiment":false}
          ],
          "group_type_mapping": {"0":"workspace"},
          "cohorts": {"41":{"type":"OR","values":[{"type":"AND","values":[{"key":"plan","type":"person","operator":"exact","value":["pro"]}]}]}},
          "minimal_flag_called_events": false,
          "property_matching_version": 2
        }}
        """
      And the SDK is initialized for native local evaluation with remote fallback and JSON arguments:
        """application/json
        {"project_token":"phc_test_key","config":{"secret_key":"phx_test_key"}}
        """

    @case:<case_id>
    Scenario Outline: Each entry that the SDK supports is evaluated locally
      Legacy getters render a number or an object as true, and an inactive flag as false.

      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"<key>","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      Then the local flag getter should return JSON <legacy_value>
      And no remote flag evaluation path should have been requested

      Examples:
        | case_id               | key                   | legacy_value |
        | mixed-v1-active       | legacy-banner         | true         |
        | mixed-v1-inactive     | legacy-retired-banner | false        |
        | mixed-v2-boolean      | layout-preview        | true         |
        | mixed-v2-string       | checkout-copy         | "short"      |
        | mixed-v2-number-split | results-per-page      | true         |
        | mixed-v2-object       | search-ranking        | true         |
        | mixed-v2-inactive     | seasonal-theme        | false        |

    Scenario: Number and object values are the payload of the legacy rendering
      When evaluate flags and read is called with JSON arguments:
        """application/json
        {"distinct_id":"person-example","options":{"only_evaluate_locally":true,"person_properties":{"plan":"pro"}},"reads":[{"method":"get_flag","key":"results-per-page"},{"method":"get_flag_payload","key":"results-per-page"},{"method":"get_flag","key":"search-ranking"},{"method":"get_flag_payload","key":"search-ranking"},{"method":"get_flag","key":"checkout-copy"},{"method":"get_flag_payload","key":"checkout-copy"}]}
        """
      Then the public snapshot outcomes should have these semantics:
        """application/json
        {"results":[{"value":true},{"payload":20},{"value":true},{"payload":{"model":"semantic","boost":1.5}},{"value":"short"},{"missing":true}]}
        """
      And no remote flag evaluation path should have been requested

    @case:<case_id>
    Scenario Outline: An unsupported entry falls back to /flags on its own
      The first rule of each document targets everyone, and the unsupported part comes
      after it. A reader that evaluated the rules it recognises would answer locally.

      Given the mock serves this /flags response body:
        """application/json
        {
          "errorsWhileComputingFlags": false,
          "flags": {
            "future-config-version": {"key":"future-config-version","value":true,"reason":{"code":"targeting_match","condition_index":0},"metadata":{"id":303,"version":2,"config_version":2,"has_experiment":false,"payload":null,"rule_type":"targeted_release","rule_id":"11111111-1111-4111-8111-111111111111"}},
            "future-rule-type": {"key":"future-rule-type","value":false,"reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":306,"version":1,"config_version":2,"has_experiment":false,"payload":null}},
            "future-rule-field": {"key":"future-rule-field","value":"standard","reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":309,"version":1,"config_version":2,"has_experiment":false,"payload":null}},
            "layout-preview": {"key":"layout-preview","value":false,"reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":302,"version":7,"config_version":2,"has_experiment":false,"payload":null}}
          },
          "requestId": "20000000-0000-4000-8000-000000000003",
          "evaluatedAt": 1800000000000
        }
        """
      When get feature flag is called with JSON arguments:
        """application/json
        {"key":"<key>","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      Then the public flag getter should return exactly JSON <remote_value>
      And exactly 1 requests containing /flags should have been received

      Examples:
        | case_id                    | key                   | remote_value |
        | unsupported-config-version | future-config-version | true         |
        | unsupported-rule-type      | future-rule-type      | false        |
        | unsupported-rule-field     | future-rule-field     | "standard"   |

    Scenario: In local-only mode an unsupported entry has no value and its siblings keep theirs
      When evaluate flags and read is called with JSON arguments:
        """application/json
        {"distinct_id":"person-example","options":{"only_evaluate_locally":true,"person_properties":{"plan":"pro"}},"reads":[{"method":"get_flag","key":"future-config-version"},{"method":"get_flag","key":"future-rule-type"},{"method":"get_flag","key":"future-rule-field"},{"method":"get_flag","key":"layout-preview"},{"method":"get_flag","key":"legacy-banner"}]}
        """
      Then the public snapshot outcomes should have these semantics:
        """application/json
        {"results":[{"missing":true},{"missing":true},{"missing":true},{"value":true},{"value":true}]}
        """
      And no remote flag evaluation path should have been requested

    Scenario: A bulk read falls back once and keeps the local results
      The remote response disagrees with the local result for "layout-preview", so the
      snapshot shows which one it kept.

      Given the mock serves this /flags response body:
        """application/json
        {
          "errorsWhileComputingFlags": false,
          "flags": {
            "future-config-version": {"key":"future-config-version","value":true,"reason":{"code":"targeting_match","condition_index":0},"metadata":{"id":303,"version":2,"config_version":2,"has_experiment":false,"payload":null,"rule_type":"targeted_release","rule_id":"11111111-1111-4111-8111-111111111111"}},
            "future-rule-type": {"key":"future-rule-type","value":false,"reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":306,"version":1,"config_version":2,"has_experiment":false,"payload":null}},
            "future-rule-field": {"key":"future-rule-field","value":"standard","reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":309,"version":1,"config_version":2,"has_experiment":false,"payload":null}},
            "layout-preview": {"key":"layout-preview","value":false,"reason":{"code":"no_rule_match","condition_index":null},"metadata":{"id":302,"version":7,"config_version":2,"has_experiment":false,"payload":null}}
          },
          "requestId": "20000000-0000-4000-8000-000000000003",
          "evaluatedAt": 1800000000000
        }
        """
      When evaluate flags and read is called with JSON arguments:
        """application/json
        {"distinct_id":"person-example","options":{"person_properties":{"plan":"pro"}},"reads":[{"method":"get_flag","key":"layout-preview"},{"method":"get_flag","key":"checkout-copy"},{"method":"get_flag","key":"future-rule-type"},{"method":"get_flag","key":"future-rule-field"}]}
        """
      Then the public snapshot outcomes should have these semantics:
        """application/json
        {"results":[{"value":true},{"value":"short"},{"value":false},{"value":"standard"}]}
        """
      And exactly 1 requests containing /flags should have been received

    @case:<case_id>
    Scenario Outline: A locally evaluated read sends the flag-called event of its record
      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"<key>","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      And pending captures are flushed
      Then exactly 1 received events should be named "$feature_flag_called"
      And a received event named "$feature_flag_called" should have property "locally_evaluated" equal to JSON true
      And a received event named "$feature_flag_called" should have property "$feature_flag_config_version" equal to JSON 2
      And a received event named "$feature_flag_called" should have property "$feature_flag_reason_code" equal to JSON "<reason_code>"
      And a received event named "$feature_flag_called" should have property "$feature_flag_response" equal to JSON <response>
      And a received event named "$feature_flag_called" should have property "$feature_flag_id" equal to JSON <id>
      And a received event named "$feature_flag_called" should have property "$feature_flag_version" equal to JSON <version>
      And no received event named "$feature_flag_called" should have property "$feature_flag_reason"
      And exactly <exposures> received events should be named "$experiment_exposure"

      Examples:
        | case_id               | key              | reason_code      | response | id  | version | exposures |
        | event-v2-boolean      | layout-preview   | targeting_match  | true     | 302 | 7       | 0         |
        | event-v2-string       | checkout-copy    | targeting_match  | "short"  | 305 | 3       | 0         |
        | event-v2-number-split | results-per-page | experiment_split | true     | 308 | 5       | 1         |
        | event-v2-object       | search-ranking   | targeting_match  | true     | 311 | 8       | 0         |
        | event-v2-inactive     | seasonal-theme   | flag_disabled    | false    | 312 | 4       | 0         |

    @case:<case_id>
    Scenario Outline: The flag-called event names the rule that decided the flag
      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"<key>","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      And pending captures are flushed
      Then a received event named "$feature_flag_called" should have property "$feature_flag_rule_id" equal to JSON "<rule_id>"
      And a received event named "$feature_flag_called" should have property "$feature_flag_rule_type" equal to JSON "<rule_type>"

      Examples:
        | case_id                 | key              | rule_id                              | rule_type          |
        | rule-targeted-release   | layout-preview   | 11111111-1111-4111-8111-111111111111 | targeted_release   |
        | rule-percentage-rollout | checkout-copy    | 22222222-2222-4222-8222-222222222222 | percentage_rollout |
        | rule-experiment         | results-per-page | 11111111-1111-4111-8111-111111111111 | experiment         |
        | rule-object-value       | search-ranking   | 11111111-1111-4111-8111-111111111111 | targeted_release   |

    Scenario: The event of an inactive flag names no rule or variant
      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"seasonal-theme","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      And pending captures are flushed
      Then exactly 1 received events should be named "$feature_flag_called"
      And no received event named "$feature_flag_called" should have property "$feature_flag_rule_id"
      And no received event named "$feature_flag_called" should have property "$feature_flag_rule_type"
      And no received event named "$feature_flag_called" should have property "$feature_flag_variant_key"
      And exactly 0 received events should be named "$experiment_exposure"

    Scenario: A locally evaluated experiment split sends the exposure
      The fixture assigns "person-example" the variant "control", whose value is 20.

      When the local flag getter is called with JSON arguments:
        """application/json
        {"key":"results-per-page","distinct_id":"person-example","person_properties":{"plan":"pro"}}
        """
      Then the local flag getter should return JSON true
      When pending captures are flushed
      Then exactly 1 received events should be named "$experiment_exposure"
      And a received event named "$experiment_exposure" should have property "locally_evaluated" equal to JSON true
      And a received event named "$experiment_exposure" should have property "$feature_flag_variant_key" equal to JSON "control"
      And a received event named "$experiment_exposure" should have property "$feature_flag_rule_id" equal to JSON "11111111-1111-4111-8111-111111111111"
      And a received event named "$experiment_exposure" should have property "$feature_flag_response" equal to JSON true
      And a received event named "$feature_flag_called" should have property "$feature_flag_variant_key" equal to JSON "control"
      And no remote flag evaluation path should have been requested
