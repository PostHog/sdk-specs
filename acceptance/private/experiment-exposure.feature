@private @canonical_behavior @acceptance @experiment_exposure @both
Feature: Experiment Exposure
  Acceptance tests for the SDK-sent $experiment_exposure event on config version 2 flags.

  # Record tables describe one /flags?v=4 record by field path. Each value cell is JSON.
  # The word absent leaves the field out of the record.
  # "a complete experiment split" is a config version 2 record with reason code
  # experiment_split, rule type experiment, and the rule id, variant key and value given.
  # For client SDKs, "for distinct id" names the identified user whose flags the SDK loaded.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  # Trigger

  Scenario: An experiment split emits both events
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "checkout-flow" with:
      | field                   | value                                  |
      | value                   | true                                   |
      | failed                  | absent                                 |
      | reason.code             | "experiment_split"                     |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | "experiment"                           |
      | metadata.rule_id        | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" |
      | metadata.variant_key    | "test"                                 |
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event properties should include:
      | property              | value                                |
      | $feature_flag_variant | test                                 |
      | $feature_flag_rule_id | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |

  Scenario: A variant whose value is false is still exposed
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
    When is feature enabled "checkout-flow" is called for distinct id "user-123"
    Then the returned feature flag value should be false
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event properties should include:
      | property               | value   |
      | $feature_flag_variant  | control |
      | $feature_flag_response | false   |

  Scenario Outline: An outcome that assigns no variant emits no exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "<flag>" with:
      | field                   | value            |
      | value                   | <value>          |
      | failed                  | <failed>         |
      | reason.code             | <reason_code>    |
      | metadata.config_version | <config_version> |
      | metadata.rule_type      | <rule_type>      |
      | metadata.rule_id        | <rule_id>        |
      | metadata.variant_key    | <variant_key>    |
    When get feature flag "<flag>" is called for distinct id "user-123"
    Then one event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued

    Examples:
      | outcome           | flag          | value | failed | reason_code         | config_version | rule_type            | rule_id                                | variant_key |
      | holdout           | checkout-flow | false | absent | "holdout"           | 2              | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      |
      | rollout exclusion | checkout-flow | false | absent | "rollout_miss"      | 2              | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      |
      | paused experiment | checkout-flow | false | absent | "experiment_paused" | 2              | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      |
      | targeted match    | beta-ui       | true  | absent | "targeting_match"   | 2              | "targeted_release"   | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" | absent      |
      | percentage match  | new-nav       | true  | absent | "targeting_match"   | 2              | "percentage_rollout" | "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45" | absent      |
      | no rule match     | beta-ui       | false | absent | "no_rule_match"     | 2              | absent               | absent                                 | absent      |
      | failed record     | checkout-flow | false | true   | "error"             | 2              | absent               | absent                                 | absent      |

  Scenario: A config version 1 experiment flag gets no SDK exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "legacy-layout" with:
      | field                   | value     |
      | value                   | "compact" |
      | metadata.config_version | 1         |
      | metadata.has_experiment | true      |
      | metadata.variant_key    | "compact" |
    When get feature flag "legacy-layout" is called for distinct id "user-123"
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should not include "$feature_flag_config_version"
    And no event named "$experiment_exposure" should be enqueued

  Scenario: A record from a server that does not send typed values gets no SDK exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "legacy-layout" with:
      | field   | value     |
      | enabled | true      |
      | variant | "compact" |
      | value   | absent    |
    When get feature flag "legacy-layout" is called for distinct id "user-123"
    Then one event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued

  Scenario: The exposure does not depend on a linked experiment
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And the record for "checkout-flow" has "metadata.has_experiment" false
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  # Typed reads

  @typed_flag_values_capable
  Scenario: A typed read that returns its caller default for a false variant still reports the assignment
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value false, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
    When a typed string read of "checkout-flow" is called for distinct id "user-123" with default "blue"
    Then the returned feature flag value should be "blue"
    And exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And the enqueued "$feature_flag_called" event property "$feature_flag_response" should equal "false"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "control"

  @typed_flag_values_capable
  Scenario: A typed read of the wrong type emits neither event and reserves nothing
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value "blue", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When a typed boolean read of "checkout-flow" is called for distinct id "user-123" with default false
    Then the returned feature flag value should be false
    And no event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued
    When a typed string read of "checkout-flow" is called for distinct id "user-123" with default "red"
    Then the returned feature flag value should be "blue"
    And exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And the enqueued "$feature_flag_called" event property "$feature_flag_response" should equal "blue"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  # Malformed splits

  Scenario Outline: A malformed split emits a diagnostic flag-called event only
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "checkout-flow" with:
      | field                   | value              |
      | value                   | "blue"             |
      | reason.code             | "experiment_split" |
      | metadata.config_version | 2                  |
      | metadata.rule_type      | <rule_type>        |
      | metadata.rule_id        | <rule_id>          |
      | metadata.variant_key    | <variant_key>      |
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the returned feature flag value should be "blue"
    And no event named "$experiment_exposure" should be enqueued
    And the enqueued "$feature_flag_called" event properties should include:
      | property                     | value            |
      | $feature_flag_config_version | 2                |
      | $feature_flag_reason_code    | experiment_split |
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_rule_id"
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_rule_type"
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_variant"

    Examples:
      | gap                | rule_type            | rule_id                                | variant_key |
      | no variant key     | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      |
      | no rule id         | "experiment"         | absent                                 | "test"      |
      | no rule type       | absent               | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "test"      |
      | another rule type  | "percentage_rollout" | "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45" | "test"      |
      | rule id not a UUID | "experiment"         | "rule-7"                               | "test"      |

  Scenario: A rule type of the wrong JSON type is a parse error, not a malformed split
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "checkout-flow" with:
      | field                   | value                                  |
      | value                   | "blue"                                 |
      | reason.code             | "experiment_split"                     |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | 2                                      |
      | metadata.rule_id        | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" |
      | metadata.variant_key    | "test"                                 |
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the read should handle the record for "checkout-flow" as a per-record parse error
    And no event named "$experiment_exposure" should be enqueued
    And no enqueued "$feature_flag_called" event for flag "checkout-flow" should have property "$feature_flag_config_version" equal to 2

  Scenario: The SDK does not guess a missing rule ID from an earlier result
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value "blue", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And the next flags response for distinct id "user-123" has a record for "checkout-flow" with:
      | field                   | value              |
      | value                   | "blue"             |
      | reason.code             | "experiment_split" |
      | metadata.config_version | 2                  |
      | metadata.rule_type      | "experiment"       |
      | metadata.rule_id        | absent             |
      | metadata.variant_key    | "test"             |
    And feature flags are reloaded
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the last enqueued "$feature_flag_called" event properties should not include "$feature_flag_rule_id"

  # Properties

  @server
  Scenario: Exposure properties of a remotely evaluated split
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has request id "7c0e5d1a-3b2f-4e6d-8a9c-0f1e2d3c4b5a" and a record for "checkout-flow" with:
      | field                   | value                                  |
      | value                   | true                                   |
      | reason.code             | "experiment_split"                     |
      | metadata.id             | 412                                    |
      | metadata.version        | 9                                      |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | "experiment"                           |
      | metadata.rule_id        | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" |
      | metadata.variant_key    | "test"                                 |
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the enqueued "$experiment_exposure" event distinct id should be "user-123"
    And the enqueued "$experiment_exposure" event properties should include:
      | property                 | value                                |
      | $feature_flag            | checkout-flow                        |
      | $feature_flag_response   | true                                 |
      | $feature_flag_variant    | test                                 |
      | $feature_flag_rule_id    | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | locally_evaluated        | false                                |
      | $feature_flag_id         | 412                                  |
      | $feature_flag_version    | 9                                    |
      | $feature_flag_request_id | 7c0e5d1a-3b2f-4e6d-8a9c-0f1e2d3c4b5a |
    And the enqueued "$experiment_exposure" event properties should not include "$feature_flag_config_version"
    And the enqueued "$experiment_exposure" event properties should not include "$feature_flag_reason_code"
    And the enqueued "$experiment_exposure" event properties should not include "$feature_flag_rule_type"
    And the enqueued "$experiment_exposure" event properties should not include "$experiment_exposure_source"
    And the enqueued "$experiment_exposure" and "$feature_flag_called" events should have different event UUIDs

  Scenario: A number-valued variant is rendered as true
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "search-ranking" with value 25, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "boosted"
    When get feature flag "search-ranking" is called for distinct id "user-123"
    Then the enqueued "$experiment_exposure" event properties should include:
      | property               | value   |
      | $feature_flag_response | true    |
      | $feature_flag_variant  | boosted |

  Scenario: An unexpected experiment ID is not sent
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And the record for "checkout-flow" has "metadata.experiment_id" 301
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event properties should not include "$feature_flag_experiment_id"
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_experiment_id"

  @server
  Scenario: Group context is carried on the exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" with group "company" "company-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
    Then the enqueued "$experiment_exposure" event property "$groups" should equal JSON {"company":"company-123"}

  # Dedupe

  Scenario: A repeated read emits one exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"

  @server @v2_local_evaluation_capable
  Scenario: A remote result after the same local assignment is not a second exposure
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions resolve "checkout-flow" for distinct id "user-123" as a complete experiment split with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And the local definitions for "checkout-flow" can no longer resolve distinct id "user-123"
    And the flags response for distinct id "user-123" has request id "9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c5d" and a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "locally_evaluated" should equal "true"

  Scenario: A flags reload does not repeat an exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And feature flags are reloaded
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"

  Scenario: A/A variants with equal values stay separate
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "pricing-page" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "control"
    When get feature flag "pricing-page" is called for distinct id "user-123"
    And the next flags response for distinct id "user-123" has a complete experiment split for "pricing-page" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And feature flags are reloaded
    And get feature flag "pricing-page" is called for distinct id "user-123"
    Then two "$experiment_exposure" events should be enqueued for flag "pricing-page"
    And the last enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  Scenario: A new experiment rule is a new exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And the next flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "8e2d4a61-0b5c-4f3a-a7d9-1c6e2b9f4d70" and variant key "test"
    And feature flags are reloaded
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then two "$experiment_exposure" events should be enqueued for flag "checkout-flow"
    And the last enqueued "$experiment_exposure" event property "$feature_flag_rule_id" should equal "8e2d4a61-0b5c-4f3a-a7d9-1c6e2b9f4d70"

  @server
  Scenario: Another group is a new exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" with group "company" "company-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And the flags response for distinct id "user-123" with group "company" "company-456" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
    And get feature flag "checkout-flow" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-456 |
    Then two "$experiment_exposure" events should be enqueued for flag "checkout-flow"

  Scenario: The flag-called entry does not suppress its exposure in a shared dedupe cache
    Given the SDK stores flag-called and exposure dedupe entries in one cache
    And the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"

  # Feature flag event decision

  @requires:flag_event_default
  Scenario: A client-level opt-out suppresses both events
    Given the SDK is initialized with token "test-token" and the client-level feature flag event default disabled
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then no event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued

  Scenario: A per-read opt-out suppresses both events and reserves nothing
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123" with tracking disabled
    Then no event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"

  Scenario: A payload-only read emits no exposure
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag payload "checkout-flow" is called for distinct id "user-123"
    Then no event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued

  @server @payload_flag_events_capable
  Scenario: An opted-in payload read follows the trigger
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag payload "checkout-flow" is called for distinct id "user-123" with flag events turned on
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  @server @payload_flag_events_capable
  Scenario: A caller-supplied match value sends no exposure and reserves nothing
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value "annual", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag payload "checkout-flow" is called for distinct id "user-123" with match value "annual" and flag events turned on
    Then no event named "$experiment_exposure" should be enqueued
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  # Bootstrap and overrides

  @client
  Scenario: A bootstrapped value emits no exposure and reserves nothing
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key           | value |
      | checkout-flow | true  |
    When get feature flag "checkout-flow" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should not include "$feature_flag_config_version"
    And no event named "$experiment_exposure" should be enqueued
    When the flags response arrives with a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And get feature flag "checkout-flow" is called
    Then two "$feature_flag_called" events should be enqueued for flag "checkout-flow"
    And the last enqueued "$feature_flag_called" event property "$feature_flag_variant" should equal "test"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  @client
  Scenario: An override suppresses the exposure
    Given the SDK is initialized with token "test-token"
    And the loaded flags response has a complete experiment split for "checkout-flow" with value "blue", rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And a client-side override sets "checkout-flow" to true
    When get feature flag "checkout-flow" is called
    Then no event named "$experiment_exposure" should be enqueued
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_rule_id"
    And the enqueued "$feature_flag_called" event properties should not include "$feature_flag_variant"

  # Local evaluation

  @server @v2_local_evaluation_capable
  Scenario: A locally evaluated split is exposed
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions resolve "checkout-flow" for distinct id "user-123" as a complete experiment split with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event properties should include:
      | property              | value |
      | locally_evaluated     | true  |
      | $feature_flag_variant | test  |
    And no remote feature flag evaluation request should have been sent

  @server
  Scenario: A locally evaluated config version 1 flag gets no SDK exposure
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions resolve "legacy-layout" for distinct id "user-123" as "compact"
    When get feature flag "legacy-layout" is called for distinct id "user-123"
    Then one event named "$feature_flag_called" should be enqueued
    And no event named "$experiment_exposure" should be enqueued

  # Best-effort capture

  Scenario: A failing exposure capture does not break the read
    Given the SDK is initialized with token "test-token" and a capture hook that throws for "$experiment_exposure"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the returned feature flag value should be true
    And no exception should be thrown

  Scenario: A failed exposure capture reserves no key and does not stop the flag-called event
    Given the SDK is initialized with token "test-token" and a capture hook that throws once for "$experiment_exposure"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And no event named "$experiment_exposure" should be enqueued
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    And the enqueued "$experiment_exposure" event property "$feature_flag_variant" should equal "test"

  Scenario: A flag-called event the queue rejects reserves no key and does not stop the exposure
    Given the SDK is initialized with token "test-token" and a capture queue that rejects the first "$feature_flag_called" event as full
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then no event named "$feature_flag_called" should be enqueued
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And exactly one event named "$experiment_exposure" should be enqueued for flag "checkout-flow"

  Scenario: An exposure that the before-send hook discards keeps its key
    Given the SDK is initialized with token "test-token" and a before-send hook that discards every "$experiment_exposure" event
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And no event named "$experiment_exposure" should be enqueued
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"
    And no event named "$experiment_exposure" should be enqueued
    And the before-send hook should have been called once for "$experiment_exposure"

  @client
  Scenario: Missing details are not fetched
    Given persistent storage contains feature flags that an older SDK version saved without typed values or rule metadata:
      | key           | value |
      | checkout-flow | test  |
    And the SDK is initialized with token "test-token"
    When get feature flag "checkout-flow" is called
    Then no event named "$experiment_exposure" should be enqueued
    And reading the flag should not send a feature flag network request
