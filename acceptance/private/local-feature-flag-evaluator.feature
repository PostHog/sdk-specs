@private @canonical_behavior @acceptance @local_feature_flag_evaluator @both
Feature: Local Feature Flag Evaluator
  Acceptance tests for the canonical local feature flag evaluator behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Evaluator returns true for a matching active boolean flag
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "beta-ui" rolled out to distinct id "user-123"
    When local feature flag "beta-ui" is evaluated for distinct id "user-123"
    Then the local evaluation result should be true

  Scenario: Evaluator returns a variant for a matching multivariate flag
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "checkout" with variant "blue" for distinct id "user-123"
    When local feature flag "checkout" is evaluated for distinct id "user-123"
    Then the local evaluation result should be "blue"

  Scenario: Evaluator signals remote fallback when required context is missing
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag definitions include a group flag "company-beta" for group type "company"
    When local feature flag "company-beta" is evaluated without group context
    Then local evaluation should be inconclusive
    When get feature flag "company-beta" is called for distinct id "user-123"
    Then a remote feature flag evaluation request should be sent for flag "company-beta"

  Scenario: Evaluator resolves payload from the matched value
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "checkout" with variant "blue" and payload:
      | field | value |
      | copy  | new   |
    When local feature flag "checkout" is evaluated for distinct id "user-123"
    Then the local evaluation payload should include:
      | field | value |
      | copy  | new   |

  Scenario: Explicit null does not match is_set
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "profile-complete" matching person property "plan" with operator "is_set"
    When local feature flag "profile-complete" is evaluated with person property "plan" explicitly set to null
    Then the local evaluation result should be false
    And the SDK should not require remote fallback solely to interpret the explicit null value

  Scenario Outline: Falsey non-null values match is_set
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "profile-complete" matching person property "plan" with operator "is_set"
    When local feature flag "profile-complete" is evaluated with person property "plan" set to <value>
    Then the local evaluation result should be true

    Examples:
      | value           |
      | false           |
      | 0               |
      | an empty string |
      | an empty list   |
      | an empty object |

  Scenario: Missing property context remains inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag definitions include a flag "profile-complete" matching person property "plan" with operator "is_set"
    When local feature flag "profile-complete" is evaluated without a "plan" entry in the supplied person properties
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible
