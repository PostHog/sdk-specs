@private @canonical_behavior @acceptance @feature_flag_called_tracker @both
Feature: Feature Flag Called Tracker
  Acceptance tests for the canonical feature flag called tracker behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Tracker emits the first flag-called event for a value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should include:
      | property     | value   |
      | $feature_flag | beta-ui |
      | $feature_flag_response | true |

  @both
  Scenario: Tracker suppresses duplicate events for the same flag value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And get feature flag "beta-ui" is called again
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

  @both
  Scenario: Tracker emits again when the flag value changes
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And cached feature flag "beta-ui" changes to "false"
    And get feature flag "beta-ui" is called
    Then two "$feature_flag_called" events should be enqueued for flag "beta-ui"

  @server
  Scenario: Tracker suppresses duplicates for the same server group context
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include a group flag "company-beta" returning true for group type "company"
    When get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
      | team    | team-1      |
    And get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | team    | team-1      |
      | company | company-123 |
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "company-beta"

  @server
  Scenario: Tracker emits again when server group context changes
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include a group flag "company-beta" returning true for group type "company"
    When get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-123 |
    And get feature flag "company-beta" is called for distinct id "user-123" with groups:
      | type    | key         |
      | company | company-456 |
    Then two "$feature_flag_called" events should be enqueued for flag "company-beta"

  @client
  Scenario: Tracker clears on identity reset
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And reset is called
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    And get feature flag "beta-ui" is called
    Then two "$feature_flag_called" events should be enqueued for flag "beta-ui"

  @both
  Scenario: Tracker clears on SDK shutdown
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    And shutdown is called
    Then feature flag called tracker state should be empty

  # Config version 2 attribution. Record tables describe one /flags?v=4 record by field
  # path. Each value cell is JSON, and the word absent leaves the field out of the record.

  @both
  Scenario: An experiment split carries the full rule tuple
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "checkout-flow" with:
      | field                   | value                                  |
      | value                   | "blue"                                 |
      | reason.code             | "experiment_split"                     |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | "experiment"                           |
      | metadata.rule_id        | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" |
      | metadata.variant_key    | "test"                                 |
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the enqueued "$feature_flag_called" event properties should include:
      | property                     | value                                |
      | $feature_flag                | checkout-flow                        |
      | $feature_flag_response       | blue                                 |
      | $feature_flag_config_version | 2                                    |
      | $feature_flag_reason_code    | experiment_split                     |
      | $feature_flag_rule_id        | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | $feature_flag_rule_type      | experiment                           |
      | $feature_flag_variant        | test                                 |
    And the enqueued event properties should not include "$feature_flag_reason"

  @both
  Scenario: A config version 2 event carries the reason code, not the description
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "beta-ui" with:
      | field                   | value                                  |
      | value                   | true                                   |
      | reason.code             | "targeting_match"                      |
      | reason.description      | "Matched rule 1"                       |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | "targeted_release"                     |
      | metadata.rule_id        | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" |
    When get feature flag "beta-ui" is called for distinct id "user-123"
    Then the enqueued event property "$feature_flag_reason_code" should equal "targeting_match"
    And the enqueued event properties should not include "$feature_flag_reason"

  @both
  Scenario Outline: A rule outcome without a variant names the rule only
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "<flag>" with:
      | field                   | value         |
      | value                   | <value>       |
      | reason.code             | <reason_code> |
      | metadata.config_version | 2             |
      | metadata.rule_type      | <rule_type>   |
      | metadata.rule_id        | <rule_id>     |
      | metadata.variant_key    | <variant_key> |
    When get feature flag "<flag>" is called for distinct id "user-123"
    Then the enqueued "$feature_flag_called" event properties should include:
      | property                     | value              |
      | $feature_flag_config_version | 2                  |
      | $feature_flag_reason_code    | <sent_reason_code> |
      | $feature_flag_rule_type      | <sent_rule_type>   |
      | $feature_flag_rule_id        | <sent_rule_id>     |
    And the enqueued event properties should not include "$feature_flag_variant"

    Examples:
      | outcome                        | flag          | value | reason_code         | rule_type            | rule_id                                | variant_key | sent_reason_code  | sent_rule_type     | sent_rule_id                         |
      | holdout                        | checkout-flow | false | "holdout"           | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      | holdout           | experiment         | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | rollout exclusion              | checkout-flow | false | "rollout_miss"      | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      | rollout_miss      | experiment         | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | paused experiment              | checkout-flow | false | "experiment_paused" | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent      | experiment_paused | experiment         | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | targeted match                 | beta-ui       | true  | "targeting_match"   | "targeted_release"   | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" | absent      | targeting_match   | targeted_release   | c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96 |
      | percentage match               | new-nav       | true  | "targeting_match"   | "percentage_rollout" | "5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45" | absent      | targeting_match   | percentage_rollout | 5a7e3b90-6c1d-4f2e-8b4a-9d0c1e2f3a45 |
      | holdout with forbidden variant | checkout-flow | false | "holdout"           | "experiment"         | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "test"      | holdout           | experiment         | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |

  @both
  Scenario Outline: An outcome without a valid rule pair carries no rule identity
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "<flag>" with:
      | field                   | value         |
      | value                   | <value>       |
      | failed                  | <failed>      |
      | reason.code             | <reason_code> |
      | metadata.config_version | 2             |
      | metadata.rule_type      | <rule_type>   |
      | metadata.rule_id        | <rule_id>     |
    When get feature flag "<flag>" is called for distinct id "user-123"
    Then the returned feature flag value should be <value>
    And the enqueued event property "$feature_flag_config_version" should equal "2"
    And the enqueued event property "$feature_flag_reason_code" should equal "<sent_reason_code>"
    And the enqueued event properties should not include "$feature_flag_rule_id"
    And the enqueued event properties should not include "$feature_flag_rule_type"
    And the enqueued event properties should not include "$feature_flag_variant"
    And no event named "$experiment_exposure" should be enqueued

    Examples:
      | outcome                       | flag          | value | failed | reason_code        | rule_type          | rule_id                                | sent_reason_code |
      | no rule match                 | beta-ui       | false | absent | "no_rule_match"    | absent             | absent                                 | no_rule_match    |
      | failed record                 | beta-ui       | false | true   | "dependency_error" | absent             | absent                                 | dependency_error |
      | unknown reason code           | beta-ui       | true  | absent | "future_reason"    | "targeted_release" | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" | future_reason    |
      | rule id without rule type     | beta-ui       | true  | absent | "targeting_match"  | absent             | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" | targeting_match  |
      | targeting match on experiment | checkout-flow | true  | absent | "targeting_match"  | "experiment"       | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | targeting_match  |

  @both
  Scenario: A record without a reason code keeps its config version
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "beta-ui" with:
      | field                   | value  |
      | value                   | true   |
      | reason                  | absent |
      | metadata.config_version | 2      |
    When get feature flag "beta-ui" is called for distinct id "user-123"
    Then the enqueued event property "$feature_flag_config_version" should equal "2"
    And the enqueued event properties should not include "$feature_flag_reason_code"
    And the enqueued event properties should not include "$feature_flag_reason"
    And the enqueued event properties should not include "$feature_flag_rule_id"
    And the enqueued event properties should not include "$feature_flag_rule_type"
    And the enqueued event properties should not include "$feature_flag_variant"
    And no event named "$experiment_exposure" should be enqueued

  @both
  Scenario: A number value is reported with its legacy rendering
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "search-ranking" with:
      | field                   | value                                  |
      | value                   | 25                                     |
      | reason.code             | "targeting_match"                      |
      | metadata.config_version | 2                                      |
      | metadata.rule_type      | "targeted_release"                     |
      | metadata.rule_id        | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" |
    When get feature flag "search-ranking" is called for distinct id "user-123"
    Then the enqueued event property "$feature_flag_response" should equal "true"

  @both
  Scenario: Config version 1 events do not change
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "legacy-layout" with:
      | field                   | value                     |
      | value                   | "compact"                 |
      | reason.code             | "condition_match"         |
      | reason.description      | "Matched condition set 1" |
      | metadata.config_version | 1                         |
      | metadata.variant_key    | "compact"                 |
    When get feature flag "legacy-layout" is called for distinct id "user-123"
    Then the enqueued event properties should not include "$feature_flag_config_version"
    And the enqueued event properties should not include "$feature_flag_reason_code"
    And the enqueued event properties should not include "$feature_flag_rule_id"
    And the enqueued event properties should not include "$feature_flag_rule_type"
    And the enqueued event properties should not include "$feature_flag_variant"
    And in an SDK that sends "$feature_flag_reason", the enqueued event property "$feature_flag_reason" should equal "Matched condition set 1"

  # Config version 2 dedupe key

  @both
  Scenario: A repeated read of the same config version 2 outcome emits one event
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    And get feature flag "checkout-flow" is called for distinct id "user-123"
    Then exactly one event named "$feature_flag_called" should be enqueued for flag "checkout-flow"

  @both
  Scenario Outline: A new config version 2 outcome with the same value emits a new event
    Given the SDK is initialized with token "test-token"
    And the flags response for distinct id "user-123" has a record for "<flag>" with:
      | field                   | value                  |
      | value                   | <value>                |
      | reason.code             | <first_reason_code>    |
      | metadata.config_version | <first_config_version> |
      | metadata.rule_type      | <first_rule_type>      |
      | metadata.rule_id        | <first_rule_id>        |
      | metadata.variant_key    | <first_variant_key>    |
    When get feature flag "<flag>" is called for distinct id "user-123"
    And the next flags response for distinct id "user-123" has a record for "<flag>" with:
      | field                   | value              |
      | value                   | <value>            |
      | reason.code             | <next_reason_code> |
      | metadata.config_version | 2                  |
      | metadata.rule_type      | <next_rule_type>   |
      | metadata.rule_id        | <next_rule_id>     |
      | metadata.variant_key    | <next_variant_key> |
    And feature flags are reloaded
    And get feature flag "<flag>" is called for distinct id "user-123"
    Then two "$feature_flag_called" events should be enqueued for flag "<flag>"
    And the last enqueued "$feature_flag_called" event property "<changed_property>" should equal "<changed_value>"

    Examples:
      | change                     | flag          | value | first_reason_code  | first_config_version | first_rule_type | first_rule_id                          | first_variant_key | next_reason_code    | next_rule_type     | next_rule_id                           | next_variant_key | changed_property             | changed_value                        |
      | another A/A variant        | pricing-page  | true  | "experiment_split" | 2                    | "experiment"    | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "control"         | "experiment_split"  | "experiment"       | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "test"           | $feature_flag_variant        | test                                 |
      | holdout after a variant    | checkout-flow | false | "experiment_split" | 2                    | "experiment"    | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "control"         | "holdout"           | "experiment"       | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent           | $feature_flag_reason_code    | holdout                              |
      | paused after a holdout     | checkout-flow | false | "holdout"          | 2                    | "experiment"    | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent            | "experiment_paused" | "experiment"       | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | absent           | $feature_flag_reason_code    | experiment_paused                    |
      | shipping the winner        | checkout-flow | true  | "experiment_split" | 2                    | "experiment"    | "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" | "test"            | "targeting_match"   | "targeted_release" | "d2b8c6f4-1e3a-4c5d-9f07-6a8b2c4e0d13" | absent           | $feature_flag_rule_id        | d2b8c6f4-1e3a-4c5d-9f07-6a8b2c4e0d13 |
      | moving to config version 2 | beta-ui       | true  | absent             | 1                    | absent          | absent                                 | absent            | "targeting_match"   | "targeted_release" | "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" | absent           | $feature_flag_config_version | 2                                    |

  # Minimal-event mode

  @both
  Scenario: Minimal event keeps config version 2 attribution
    Given the SDK is initialized with token "test-token"
    And the server reports the minimal-event gate as enabled
    And the flags response for distinct id "user-123" has a complete experiment split for "checkout-flow" with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
    And the record for "checkout-flow" has "metadata.has_experiment" false
    And a super property "team" with value "growth" is registered
    When get feature flag "checkout-flow" is called for distinct id "user-123"
    Then the enqueued "$feature_flag_called" event properties should include:
      | property                     | value                                |
      | $feature_flag                | checkout-flow                        |
      | $feature_flag_response       | true                                 |
      | $feature_flag_config_version | 2                                    |
      | $feature_flag_reason_code    | experiment_split                     |
      | $feature_flag_rule_id        | 3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13 |
      | $feature_flag_rule_type      | experiment                           |
      | $feature_flag_variant        | test                                 |
    And the enqueued event properties should not include "team"
    And the enqueued event properties should not include "$feature_flag_reason"

  @both
  Scenario: A minimized config version 1 event does not keep attribution names
    Given the SDK is initialized with token "test-token"
    And the server reports the minimal-event gate as enabled
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    And the flag "beta-ui" is a config version 1 flag that reports has_experiment as false
    And a super property "$feature_flag_rule_id" with value "c41f9e07-2d6b-4a83-b5e1-7f0a3c8d2e96" is registered
    When get feature flag "beta-ui" is called
    Then the enqueued "$feature_flag_called" event should be minimized per the allowlist
    And the enqueued event properties should not include "$feature_flag_rule_id"
    And the enqueued event properties should not include "$feature_flag_config_version"
