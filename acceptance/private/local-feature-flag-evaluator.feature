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

  Scenario: Explicit null matches is_set
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "profile-complete" matching person property "plan" with operator "is_set"
    When local feature flag "profile-complete" is evaluated with person property "plan" explicitly set to null
    Then the local evaluation result should be true
    And the SDK should not require remote fallback solely to interpret the explicit null value

  Scenario Outline: Other falsey present values match is_set
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

  Scenario: Missing property context leaves is_set inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag definitions include a flag "profile-complete" matching person property "plan" with operator "is_set"
    When local feature flag "profile-complete" is evaluated without a "plan" entry in the supplied person properties
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

  Scenario: Explicit null does not match is_not_set
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "profile-incomplete" matching person property "plan" with operator "is_not_set"
    When local feature flag "profile-incomplete" is evaluated with person property "plan" explicitly set to null
    Then the local evaluation result should be false
    And the SDK should not require remote fallback solely to interpret the explicit null value

  Scenario Outline: Other falsey present values do not match is_not_set
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "profile-incomplete" matching person property "plan" with operator "is_not_set"
    When local feature flag "profile-incomplete" is evaluated with person property "plan" set to <value>
    Then the local evaluation result should be false

    Examples:
      | value           |
      | false           |
      | 0               |
      | an empty string |
      | an empty list   |
      | an empty object |

  Scenario: Missing property context leaves is_not_set inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag definitions include a flag "profile-incomplete" matching person property "plan" with operator "is_not_set"
    When local feature flag "profile-incomplete" is evaluated without a "plan" entry in the supplied person properties
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

  @server
  Scenario: The first matching condition wins without variant-priority sorting
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "checkout" whose first condition matches person property "plan" equal to "pro" with no variant override
    And local feature flag "checkout" has a later catch-all condition overriding the variant to "test"
    And distinct id "user-123" hashes to variant "control" for local feature flag "checkout"
    When local feature flag "checkout" is evaluated for distinct id "user-123" with person property "plan" equal to "pro"
    Then the local evaluation result should be "control"
    And the later "test" override should not reorder or replace the first matching condition

  @server
  Scenario: Filters are ANDed within a condition and conditions are ORed
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "beta-ui" has a first condition requiring person property "plan" equal to "pro" and person property "region" equal to "us"
    And local feature flag "beta-ui" has a second condition requiring person property "plan" equal to "pro"
    When local feature flag "beta-ui" is evaluated with person properties "plan" equal to "pro" and "region" equal to "eu"
    Then the first condition should not match
    And the local evaluation result should be true from the second condition

  @server
  Scenario: Early exit stops after a targeted rollout exclusion
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "beta-ui" has early exit enabled
    And its first condition matches person property "plan" equal to "pro" with rollout percentage 0.0
    And its second condition is a catch-all with rollout percentage 100.0
    When local feature flag "beta-ui" is evaluated with person property "plan" equal to "pro"
    Then the local evaluation result should be false
    And the local evaluation result should not include a variant or payload
    And the second condition should not be evaluated as a match

  @server
  Scenario: Disabled early exit allows a later condition to match
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "beta-ui" omits early exit or sets it to false
    And its first condition matches person property "plan" equal to "pro" with rollout percentage 0.0
    And its second condition is a catch-all with rollout percentage 100.0
    When local feature flag "beta-ui" is evaluated with person property "plan" equal to "pro"
    Then the local evaluation result should be true from the second condition

  @server
  Scenario: Early exit does not stop after a property mismatch
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "beta-ui" has early exit enabled
    And its first condition requires person property "plan" equal to "enterprise" with rollout percentage 0.0
    And its second condition is a catch-all with rollout percentage 100.0
    When local feature flag "beta-ui" is evaluated with person property "plan" equal to "pro"
    Then the first condition should be treated as a property mismatch rather than a rollout exclusion
    And the local evaluation result should be true from the second condition

  @server
  Scenario: Early exit does not stop after an inconclusive condition
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "mixed-beta" has early exit enabled
    And its first group-aggregated condition has an available group key but missing required group properties and rollout percentage 0.0
    And its second person-aggregated condition matches person property "plan" equal to "pro" with rollout percentage 100.0
    When local feature flag "mixed-beta" is evaluated with person property "plan" equal to "pro"
    Then the first condition should remain inconclusive and should not trigger early exit
    And the local evaluation result should be true from the second condition

  @server
  Scenario: A valid condition variant override wins
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "checkout" with variants "control" and "test"
    And its first matching condition specifies variant override "test"
    And distinct id "user-123" hashes to variant "control" for local feature flag "checkout"
    When local feature flag "checkout" is evaluated for distinct id "user-123"
    Then the local evaluation result should be "test"

  @server
  Scenario: An invalid condition variant override falls back to deterministic assignment
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "checkout" with variants "control" and "test"
    And its first matching condition specifies variant override "unknown"
    And distinct id "user-123" hashes to variant "control" for local feature flag "checkout"
    When local feature flag "checkout" is evaluated for distinct id "user-123"
    Then the local evaluation result should be "control"

  @server
  Scenario: An omitted condition aggregation inherits the legacy flag aggregation
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "company-beta" has flag-level aggregation for group type "company"
    And its condition omits the aggregation group type index
    And the condition requires company property "tier" equal to "enterprise"
    When local feature flag "company-beta" is evaluated for company "acme" with company property "tier" equal to "enterprise"
    Then the condition should match using the flag-level company aggregation

  @server
  Scenario: Explicit person aggregation overrides a flag-level group aggregation
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "mixed-beta" has flag-level aggregation for group type "company"
    And its condition sets the aggregation group type index to null
    And the condition requires person property "plan" equal to "pro"
    When local feature flag "mixed-beta" is evaluated with person property "plan" equal to "pro"
    Then the condition should match using person context and person bucketing

  @server
  Scenario Outline: One condition can AND person and group filters
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "mixed-beta" has a condition aggregating on group type "company"
    And the condition requires person property "plan" equal to "pro"
    And the condition requires company property "size" equal to "enterprise"
    When local feature flag "mixed-beta" is evaluated with person property "plan" equal to <plan> and company property "size" equal to <size>
    Then the condition match result should be <matches>

    Examples:
      | plan   | size       | matches |
      | "pro"  | "enterprise" | true    |
      | "free" | "enterprise" | false   |
      | "pro"  | "startup"    | false   |

  @server
  Scenario: The matching condition selects the multivariate hash identity
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a multivariate flag "mixed-checkout" with a group-aggregated condition followed by a person-aggregated condition
    And the group condition cannot be resolved from the supplied group context
    And the person condition matches
    And the person's bucketing identifier hashes to variant "control"
    When local feature flag "mixed-checkout" is evaluated
    Then the local evaluation result should be "control"
    And variant assignment should use the person identifier from the matching condition rather than a group key

  @server
  Scenario: Missing device id blocks only person-aggregated conditions
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "mixed-device" uses device-id bucketing
    And it has a person-aggregated condition followed by a group-aggregated condition
    And no device id is supplied
    And the required group key is supplied and the group condition matches
    When local feature flag "mixed-device" is evaluated
    Then the group condition should determine the local evaluation result
    And the person condition should not fall back to hashing the distinct id

  @server
  Scenario: A device-bucketed person flag without a device id is inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "device-only" uses device-id bucketing and has only person-aggregated conditions
    When local feature flag "device-only" is evaluated without a device id
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

  @server
  Scenario Outline: Flag dependency filters compare evaluated values
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "checkout" evaluates to <actual>
    And local feature flag "banner" has a "flag_evaluates_to" condition requiring flag "checkout" to evaluate to <expected>
    When local feature flag "banner" is evaluated
    Then the dependency filter match result should be <matches>

    Examples:
      | actual    | expected | matches |
      | true      | true     | true    |
      | "test"    | true     | true    |
      | false     | false    | true    |
      | true      | false    | false   |
      | "test"    | "test"   | true    |
      | "test"    | "Test"   | false   |
      | "control" | "test"   | false   |

  @server
  Scenario: An unresolved dependency affects only the dependent flag
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "banner" depends on a flag definition that is missing or cannot be resolved locally
    And independent local feature flag "beta-ui" can be evaluated from local definitions and context
    When local feature flags "banner" and "beta-ui" are evaluated
    Then local evaluation should be inconclusive for "banner"
    And "beta-ui" should still be evaluated locally

  @server
  Scenario: Operator omission defaults to exact
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "operator-default" has a person property condition that omits its operator and has condition value "PRO"
    When local feature flag "operator-default" is evaluated with supplied property value "pro"
    Then the criterion should match using operator "exact"

  @server
  Scenario Outline: Unavailable or malformed criteria preserve the correct result state
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "criterion-state" has a condition with operator <operator> and condition value <condition>
    And independent local feature flag "beta-ui" can be evaluated from local definitions and context
    When local feature flag "criterion-state" is evaluated with <property_context>
    Then the criterion result should be <result>
    And "beta-ui" should still be evaluated locally

    Examples:
      | operator          | condition | property_context                                      | result       |
      | "exact"          | "pro"     | the required key omitted                             | inconclusive |
      | "is_not"         | "pro"     | the required key omitted                             | inconclusive |
      | "is_not_set"     | omitted   | the required key omitted from partial local context  | inconclusive |
      | "exact"          | omitted   | property value "pro" present                        | inconclusive |
      | "future_operator" | "pro"          | property value "pro" present                        | inconclusive |
      | "gt"              | 10             | property value "not-a-number" present               | false        |
      | "gt"              | "not-a-number" | property value 10 present                            | inconclusive |

  @server
  Scenario Outline: Exact and is_not use canonical coercion and condition-list membership
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "exact-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "exact-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator | condition    | property | matches |
      | "exact"  | "US"         | "us"     | true    |
      | "exact"  | 1            | "1"      | true    |
      | "exact"  | true         | "TRUE"   | true    |
      | "exact"  | "null"       | null     | true    |
      | "exact"  | ["US", "CA"] | "us"     | true    |
      | "exact"  | ["US", "CA"] | "gb"     | false   |
      | "is_not" | "US"         | "us"     | false   |
      | "is_not" | ["US", "CA"] | "gb"     | true    |

  @server
  Scenario Outline: String criteria compare the supplied property against the condition value
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "string-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "string-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator              | condition             | property            | matches |
      | "icontains"           | "EXAMPLE"             | "Admin@example.com" | true    |
      | "not_icontains"       | "EXAMPLE"             | "Admin@example.com" | false   |
      | "starts_with"         | "ADMIN@"              | "admin@example.com" | true    |
      | "not_starts_with"     | "USER@"               | "admin@example.com" | true    |
      | "ends_with"           | ".COM"                | "admin@example.com" | true    |
      | "not_ends_with"       | ".ORG"                | "admin@example.com" | true    |
      | "icontains_multi"     | ["enterprise", "PRO"] | "pro account"       | true    |
      | "not_icontains_multi" | ["enterprise", "PRO"] | "pro account"       | false   |
      | "icontains_multi"     | []                    | "pro account"       | false   |
      | "not_icontains_multi" | []                    | "pro account"       | true    |

  @server
  Scenario: A starts_with filter matches locally
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "enterprise-ui" matching person property "email" with operator "starts_with" and value "admin@"
    When local feature flag "enterprise-ui" is evaluated for a person with property "email" equal to "Admin@Example.com"
    Then the local evaluation result should be true

  @server
  Scenario: A starts_with filter is inconclusive when the property is missing
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include a flag "enterprise-ui" matching person property "email" with operator "starts_with" and value "admin@"
    When local feature flag "enterprise-ui" is evaluated for a person with no "email" property
    Then local evaluation should be inconclusive

  @server
  Scenario Outline: Regex criteria search safely without implicit flags or anchors
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "regex-criterion" has a person property condition with operator <operator> and pattern <pattern>
    When local feature flag "regex-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator    | pattern         | property            | matches |
      | "regex"     | "example\\.com" | "admin@example.com" | true    |
      | "regex"     | "^example"      | "admin@example.com" | false   |
      | "regex"     | "EXAMPLE"       | "admin@example.com" | false   |
      | "not_regex" | "example\\.org" | "admin@example.com" | true    |
      | "regex"     | "["              | "admin@example.com" | false   |
      | "not_regex" | "["              | "admin@example.com" | false   |

  @server
  Scenario Outline: Numeric ordering uses strict numeric semantics
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "numeric-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "numeric-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator | condition | property | matches |
      | "gt"     | "9"       | "10"     | true    |
      | "gte"    | 10        | "10.0"   | true    |
      | "lt"     | 10        | 9        | true    |
      | "lte"    | 10        | 11       | false   |
      | "min"    | 10        | 10       | true    |
      | "max"    | 10        | 11         | false   |
      | "gt"     | 9         | "10px"     | false   |
      | "gt"     | 9         | "NaN"      | false   |
      | "lt"     | 9         | "Infinity" | false   |

  @server
  Scenario Outline: Dynamic-cohort ranges are inclusive and validate both bounds
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "range-criterion" references a dynamic cohort property condition with operator <operator> and condition value <condition>
    When local feature flag "range-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator      | condition | property       | matches |
      | "between"     | [10, 20]  | 10             | true    |
      | "between"     | [10, 20]  | 20             | true    |
      | "between"     | [10, 20]  | 21             | false   |
      | "not_between" | [10, 20]  | 21             | true         |
      | "not_between" | [10, 20]  | "not-a-number" | false        |
      | "not_between" | [10, 20]  | "NaN"          | false        |
      | "between"     | [20, 10]  | 15             | inconclusive |
      | "not_between" | [10]      | 15             | inconclusive |

  @server
  Scenario Outline: Date criteria normalize offsets and preserve strict boundaries
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK clock is fixed at "2025-01-08T00:00:00Z"
    And local feature flag "date-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "date-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator          | condition              | property                     | matches |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | "2025-01-01T12:00:00+02:00" | true    |
      | "is_date_after"   | "2025-01-01T10:00:00Z" | "2025-01-01T10:00:01Z"      | true    |
      | "is_date_after"   | "2025-01-01T10:00:00Z" | "2025-01-01T10:00:00Z"      | false   |
      | "is_date_before"  | "2025-01-01T10:00:00Z" | "2025-01-01T09:59:59Z"      | true    |
      | "is_date_exact"   | "2025-01-01T10:00:00"  | "2025-01-01T10:00:00Z"      | true         |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | 1735725600                   | true         |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | "1735725600"                 | true         |
      | "is_date_after"   | "-7d"                  | "2025-01-02T00:00:00Z"      | true         |
      | "is_date_before"  | "2025-01-01T10:00:00Z" | "not-a-date"                 | false        |
      | "is_date_before"  | "not-a-date"            | "2025-01-01T10:00:00Z"      | inconclusive |

  @server
  Scenario Outline: Relative date criteria use the canonical lookback grammar
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK clock is fixed at "2025-01-08T00:00:00Z"
    And local feature flag "relative-date-criterion" has a person property condition with operator "is_date_exact" and condition value <condition>
    When local feature flag "relative-date-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | condition | property                | matches      |
      | "-1h"     | "2025-01-07T23:00:00Z" | true         |
      | "1d"      | "2025-01-07T00:00:00Z" | true         |
      | "-1w"     | "2025-01-01T00:00:00Z" | true         |
      | "1m"      | "2024-12-08T00:00:00Z" | true         |
      | "-1y"     | "2024-01-08T00:00:00Z" | true         |
      | "10000d"  | "2025-01-01T00:00:00Z" | inconclusive |

  @server
  Scenario Outline: Semantic-version comparison uses normalized SemVer precedence
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "semver-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "semver-criterion" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator     | condition          | property          | matches |
      | "semver_eq"  | "1.2.0"            | " v1.02 "         | true    |
      | "semver_neq" | "1.2.0"            | "1.2.1"           | true    |
      | "semver_gt"  | "1.2.3-beta.1"     | "1.2.3"           | true    |
      | "semver_gte" | "1.2.3"            | "1.2.3+build.7"   | true    |
      | "semver_lt"  | "2.0.0"            | "1.9.9"           | true         |
      | "semver_lte" | "1.2.3"            | "1.2.4"           | false        |
      | "semver_neq" | "1.2.3"            | "not-a-version"   | false        |
      | "semver_eq"  | "not-a-version"    | "1.2.3"           | inconclusive |

  @server
  Scenario Outline: Semantic-version ranges are lower-inclusive and upper-exclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "semver-range" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "semver-range" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator           | condition | property | matches |
      | "semver_tilde"    | "1.2.3"        | "1.2.3"  | true         |
      | "semver_tilde"    | "1.2.3"        | "1.2.9"  | true         |
      | "semver_tilde"    | "1.2.3"        | "1.3.0"  | false        |
      | "semver_caret"    | "1.2.3"        | "1.2.3"  | true         |
      | "semver_caret"    | "1.2.3"        | "1.9.9"  | true         |
      | "semver_caret"    | "1.2.3"        | "2.0.0"  | false        |
      | "semver_caret"    | "0.2.3"        | "0.3.0"  | false        |
      | "semver_wildcard" | "1.2.*"        | "1.2.0"  | true         |
      | "semver_wildcard" | "1.2.*"        | "1.2.99" | true         |
      | "semver_wildcard" | "1.2.*"        | "1.3.0"  | false        |
      | "semver_tilde"    | "not-a-range"  | "1.2.3"  | inconclusive |

  @server
  Scenario Outline: Cohort membership operators compare the referenced membership
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "cohort-criterion" references cohort "42" with operator <operator>
    And cohort "42" has local membership result <membership>
    When local feature flag "cohort-criterion" is evaluated locally
    Then the criterion match result should be <matches>

    Examples:
      | operator | membership | matches |
      | omitted  | true       | true    |
      | "in"     | false      | false   |
      | "not_in" | true       | false   |
      | "not_in" | false      | true    |

  @server
  Scenario: Negation does not turn an inconclusive cohort leaf into a match
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "cohort-criterion" references a dynamic cohort with a negated leaf whose required person property is unavailable locally
    When local feature flag "cohort-criterion" is evaluated locally
    Then the cohort criterion should be inconclusive
    And the negation should not turn it into a match
    And remote evaluation should remain eligible
