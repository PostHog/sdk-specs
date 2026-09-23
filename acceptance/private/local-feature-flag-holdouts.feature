@private @canonical_behavior @acceptance @local_feature_flag_evaluator @server
Feature: Local feature flag experiment holdouts
  Applies to SDKs evaluating downloaded definitions, not consumers of remote flag values.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token" and local evaluation enabled

  Scenario: Holdout precedes targeting and ordinary variant assignment
    Given an active flag "checkout" has holdout id 727 with exclusion percentage 100
    And its release conditions require an unavailable person property, have rollout percentage 0, and override the variant to "test"
    And its multivariate variants contain only "control" and "test"
    When the flag is evaluated locally
    Then the result should be "holdout-727" without evaluating release conditions or requiring remote fallback

  Scenario: Inactive flags remain disabled
    Given an inactive flag has holdout id 727 with exclusion percentage 100
    When the flag is evaluated locally
    Then the result should be false

  Scenario: Absent holdouts preserve ordinary assignment
    Given an active flag has no holdout configuration and a matching condition selecting "control"
    When the flag is evaluated locally
    Then the result should be "control"

  Scenario: Bulk evaluation and dependencies use the holdout string
    Given active flag "checkout" has holdout id 727 with exclusion percentage 100
    And another flag depends on "checkout" equaling "holdout-727"
    When the flags are evaluated locally in one bulk pass
    Then "checkout" should resolve to "holdout-727"
    And the dependency comparison should match that string rather than a regular variant

  Scenario Outline: Membership uses the exact server hash rather than a dot-separated prefix
    Given an active flag has holdout id 727 with exclusion percentage 20 and otherwise selects "control"
    When it is evaluated with person bucketing value "<identity>"
    Then the holdout hash should be approximately <hash>
    And the result should be "<result>"

    Examples:
      | identity | hash                | result      |
      | user-1   | 0.17805599206573022 | holdout-727 |
      | user-5   | 0.6563813925994418  | control     |

  Scenario Outline: Fractional percentage boundaries are inclusive and clamped
    Given a holdout membership calculation with hash 0.125
    When the exclusion percentage is <percentage>
    Then holdout membership should be <membership>

    Examples:
      | percentage | membership |
      | -10        | false      |
      | 0          | false      |
      | 12.4       | false      |
      | 12.5       | true       |

  Scenario Outline: Full membership does not hash
    Given a holdout membership calculation
    When the exclusion percentage is <percentage>
    Then the identifier should be held out without computing a hash

    Examples:
      | percentage |
      | 100        |
      | 150        |

  Scenario: Exact zero hash preserves the inclusive backend boundary
    Given a holdout membership calculation with hash 0
    When the exclusion percentage is 0
    Then holdout membership should be true

  Scenario: Flag-level group identity determines membership
    Given an active group-aggregated flag has holdout id 727 with exclusion percentage 20
    And its flag-level group key is "user-1" and the person's distinct id is "user-5"
    When the flag is evaluated locally
    Then the result should be "holdout-727" using the group key

  Scenario: Device-bucketed flags use the device identity
    Given an active person flag uses device-id bucketing and holdout id 727 with exclusion percentage 20
    And the device id is "user-1" and the distinct id is "user-5"
    When the flag is evaluated locally
    Then the result should be "holdout-727" using the device id

  @flag_definition_loader
  Scenario: Shared definition caches preserve holdout fields
    Given the definition API returns an active flag with holdout id 727 and exclusion percentage 12.5
    When one SDK instance stores those definitions in a configured shared cache and another instance loads them
    Then the loaded flag should retain holdout id 727 and exclusion percentage 12.5
    And both instances should calculate identical holdout membership for the same bucketing identity

  @flag_definition_loader
  Scenario: Refresh removes stale holdout configuration
    Given cached definitions contain an active flag with a 100 percent holdout
    When a replacement definition snapshot omits that flag's holdout configuration
    Then subsequent local evaluations should use ordinary release conditions rather than the previous holdout
