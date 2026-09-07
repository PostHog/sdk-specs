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
  Scenario: Inconclusive state is preserved when no later condition matches
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "uncertain-beta" has a first condition that cannot be resolved from the supplied local context
    And every later condition of local feature flag "uncertain-beta" definitively does not match
    When local feature flag "uncertain-beta" is evaluated
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

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
  Scenario: An unresolved dependency is inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "banner" depends on a flag definition that is missing or cannot be resolved locally
    When local feature flag "banner" is evaluated
    Then local evaluation should be inconclusive for "banner"
    And remote evaluation should remain eligible

  @server
  Scenario Outline: An inactive dependency resolves as false
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And inactive local feature flag "A" is retained for dependency evaluation
    And active local feature flag "dependent" requires flag "A" to evaluate to <expected>
    When local feature flag "dependent" is evaluated
    Then the dependency filter match result should be <matches>

    Examples:
      | expected | matches |
      | false    | true    |
      | true     | false   |

  @server
  Scenario Outline: Omitted and null operators default to exact
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "operator-default" has a person property condition with <operator_state> and condition value "PRO"
    When local feature flag "operator-default" is evaluated with supplied property value "pro"
    Then the criterion should match using operator "exact"

    Examples:
      | operator_state                 |
      | an omitted operator            |
      | an explicit JSON null operator |

  @server
  Scenario Outline: Unavailable or malformed criteria preserve the correct result state
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "criterion-state" has a condition with operator <operator> and condition value <condition>
    When local feature flag "criterion-state" is evaluated with <property_context>
    Then the criterion result should be <result>

    Examples:
      | operator          | condition | property_context                                      | result       |
      | "exact"          | "pro"     | the required key omitted                             | inconclusive |
      | "is_not"         | "pro"     | the required key omitted                             | inconclusive |
      | "is_not_set"     | omitted   | the required key omitted from partial local context  | inconclusive |
      | "exact"          | omitted   | property value "pro" present                        | inconclusive |
      | "future_operator" | "pro"          | property value "pro" present                        | inconclusive |
      | "gt"              | "10"           | property value "not-a-number" present               | false        |
      | "gt"              | "not-a-number" | property value 10 present                            | inconclusive |

  @server
  Scenario Outline: Exact and is_not preserve legacy equality when version is missing
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response omits top-level "property_matching_version"
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
      | "exact"  | false        | "banana" | true    |
      | "exact"  | ["false"]    | 0        | true    |
      | "exact"  | ["true", "false"] | "true" | false |
      | "exact"  | ["true", "false"] | "pro"  | true  |
      | "exact"  | []           | true     | true    |
      | "exact"  | []           | "us"     | false   |
      | "is_not" | []           | "us"     | true    |

  # Version cells are JSON numbers; omitted means the top-level field is absent.
  # Every property value below is present, including JSON null and empty arrays.
  @server
  Scenario Outline: Versioned equality covers the six service regression rows and is_not complements
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "versioned-exact" has a person property condition with operator "exact" and condition value <condition>
    And local feature flag "versioned-is-not" has the same condition with operator "is_not"
    When local feature flag "versioned-exact" is evaluated with supplied property value <property>
    Then the criterion match result should be <exact>
    When local feature flag "versioned-is-not" is evaluated with supplied property value <property>
    Then the criterion match result should be <is_not>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | condition        | property | exact | is_not |
      | omitted | false            | "banana" | true  | false  |
      | omitted | false            | 0        | true  | false  |
      | omitted | ["true","false"] | "true"   | false | true   |
      | omitted | ["true","false"] | "pro"    | true  | false  |
      | omitted | []               | true     | true  | false  |
      | omitted | []               | []       | true  | false  |
      | 1       | false            | "banana" | true  | false  |
      | 1       | false            | 0        | true  | false  |
      | 1       | ["true","false"] | "true"   | false | true   |
      | 1       | ["true","false"] | "pro"    | true  | false  |
      | 1       | []               | true     | true  | false  |
      | 1       | []               | []       | true  | false  |
      | 2       | false            | "banana" | false | true   |
      | 2       | false            | 0        | false | true   |
      | 2       | ["true","false"] | "true"   | true  | false  |
      | 2       | ["true","false"] | "pro"    | false | true   |
      | 2       | []               | true     | true  | false  |
      | 2       | []               | []       | true  | false  |

  @server
  Scenario Outline: Versioned equality preserves known null whole arrays empty-filter truthiness and normalization
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "versioned-exact" has a person property condition with operator "exact" and condition value <condition>
    And local feature flag "versioned-is-not" has the same condition with operator "is_not"
    When local feature flag "versioned-exact" is evaluated with supplied property value <property>
    Then the criterion match result should be <exact>
    When local feature flag "versioned-is-not" is evaluated with supplied property value <property>
    Then the criterion match result should be <is_not>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | condition             | property           | exact | is_not |
      | omitted | true                  | [true]             | true  | false  |
      | omitted | false                 | "FALSE"            | true  | false  |
      | omitted | false                 | null               | true  | false  |
      | omitted | false                 | ""                 | true  | false  |
      | omitted | false                 | {}                 | true  | false  |
      | omitted | []                    | "TRUE"             | true  | false  |
      | omitted | []                    | [true,["TRUE",[]]] | true  | false  |
      | omitted | []                    | [true,[false]]     | false | true   |
      | omitted | []                    | false              | false | true   |
      | omitted | []                    | 0                  | false | true   |
      | omitted | []                    | 1                  | false | true   |
      | omitted | []                    | "banana"           | false | true   |
      | omitted | []                    | null               | false | true   |
      | omitted | ["TrUe","FALSE"]      | true               | false | true   |
      | omitted | ["TrUe","FALSE"]      | false              | true  | false  |
      | omitted | [false,"PRO"]         | "pro"              | true  | false  |
      | omitted | [false,"PRO"]         | "banana"           | false | true   |
      | omitted | ["FREE","PRO"]        | "pro"              | true  | false  |
      | omitted | [[true],"PRO"]        | [true]             | true  | false  |
      | omitted | [[true]]              | true               | true  | false  |
      | omitted | ["null","PRO"]        | null               | true  | false  |
      | omitted | [{"a":2,"b":1},"PRO"] | {"b":1,"a":2}      | true  | false  |
      | omitted | ["Ä","PRO"]           | "ä"                | true  | false  |
      | 1       | true                  | [true]             | true  | false  |
      | 1       | false                 | "FALSE"            | true  | false  |
      | 1       | false                 | null               | true  | false  |
      | 1       | false                 | ""                 | true  | false  |
      | 1       | false                 | {}                 | true  | false  |
      | 1       | []                    | "TRUE"             | true  | false  |
      | 1       | []                    | [true,["TRUE",[]]] | true  | false  |
      | 1       | []                    | [true,[false]]     | false | true   |
      | 1       | []                    | false              | false | true   |
      | 1       | []                    | 0                  | false | true   |
      | 1       | []                    | 1                  | false | true   |
      | 1       | []                    | "banana"           | false | true   |
      | 1       | []                    | null               | false | true   |
      | 1       | ["TrUe","FALSE"]      | true               | false | true   |
      | 1       | ["TrUe","FALSE"]      | false              | true  | false  |
      | 1       | [false,"PRO"]         | "pro"              | true  | false  |
      | 1       | [false,"PRO"]         | "banana"           | false | true   |
      | 1       | ["FREE","PRO"]        | "pro"              | true  | false  |
      | 1       | [[true],"PRO"]        | [true]             | true  | false  |
      | 1       | [[true]]              | true               | true  | false  |
      | 1       | ["null","PRO"]        | null               | true  | false  |
      | 1       | [{"a":2,"b":1},"PRO"] | {"b":1,"a":2}      | true  | false  |
      | 1       | ["Ä","PRO"]           | "ä"                | true  | false  |
      | 2       | true                  | [true]             | false | true   |
      | 2       | false                 | "FALSE"            | true  | false  |
      | 2       | false                 | null               | false | true   |
      | 2       | false                 | ""                 | false | true   |
      | 2       | false                 | {}                 | false | true   |
      | 2       | []                    | "TRUE"             | true  | false  |
      | 2       | []                    | [true,["TRUE",[]]] | true  | false  |
      | 2       | []                    | [true,[false]]     | false | true   |
      | 2       | []                    | false              | false | true   |
      | 2       | []                    | 0                  | false | true   |
      | 2       | []                    | 1                  | false | true   |
      | 2       | []                    | "banana"           | false | true   |
      | 2       | []                    | null               | false | true   |
      | 2       | ["TrUe","FALSE"]      | true               | true  | false  |
      | 2       | ["TrUe","FALSE"]      | false              | true  | false  |
      | 2       | [false,"PRO"]         | "pro"              | true  | false  |
      | 2       | [false,"PRO"]         | "banana"           | false | true   |
      | 2       | ["FREE","PRO"]        | "pro"              | true  | false  |
      | 2       | [[true],"PRO"]        | [true]             | true  | false  |
      | 2       | [[true]]              | true               | false | true   |
      | 2       | ["null","PRO"]        | null               | true  | false  |
      | 2       | [{"a":2,"b":1},"PRO"] | {"b":1,"a":2}      | true  | false  |
      | 2       | ["Ä","PRO"]           | "ä"                | true  | false  |

  @server
  Scenario Outline: Missing equality context remains inconclusive in every matching version
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "missing-versioned" has a person property condition for key "plan" with operator <operator> and condition value false
    When local feature flag "missing-versioned" is evaluated without a "plan" entry in the supplied person properties
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

    Examples:
      | version | operator |
      | omitted | "exact"  |
      | omitted | "is_not" |
      | 1       | "exact"  |
      | 1       | "is_not" |
      | 2       | "exact"  |
      | 2       | "is_not" |

  @server
  Scenario Outline: Unknown matching versions never activate explicit matching
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "unknown-version" has a person property condition with operator "exact" and condition value false
    When local feature flag "unknown-version" is evaluated with supplied property value "banana"
    Then the criterion should match using legacy semantics unless an existing unsupported-version policy returns inconclusive
    And it should not return the explicit matching no-match result
    And evaluation should not throw

    Examples:
      | version |
      | 0       |
      | 3       |

  @server
  Scenario Outline: Person group and recursive cohort equality share the snapshot version
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "person-versioned" has a person property condition for key "plan" with operator <operator> and condition value false
    And the snapshot group type mapping maps index 0 to "company"
    And local feature flag "group-versioned" has a company group condition for key "plan" with operator <operator> and condition value false
    And local feature flag "cohort-versioned" requires membership in dynamic cohort "42"
    And cohort "42" is an AND group referencing cohort "43"
    And cohort "43" is an OR group containing one person property leaf for key "plan" with operator <operator> and condition value false
    When all three flags are evaluated locally for distinct id "user-123" with person property "plan" equal to "banana" and company "acme" with group property "plan" equal to "banana"
    Then each local evaluation result should be <matches>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | operator | matches |
      | omitted | "exact"  | true    |
      | omitted | "is_not" | false   |
      | 1       | "exact"  | true    |
      | 1       | "is_not" | false   |
      | 2       | "exact"  | false   |
      | 2       | "is_not" | true    |

  @server
  Scenario Outline: Recursive cohort leaf negation applies after versioned equality
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "cohort-versioned" requires membership in dynamic cohort "42"
    And cohort "42" is an AND group referencing cohort "43"
    And cohort "43" is an OR group containing one person property leaf with operator <operator> and condition value false
    And the leaf sets negation to true
    When local feature flag "cohort-versioned" is evaluated with supplied person property value "banana"
    Then the local evaluation result should be <matches>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | operator | matches |
      | omitted | "exact"  | false   |
      | omitted | "is_not" | true    |
      | 1       | "exact"  | false   |
      | 1       | "is_not" | true    |
      | 2       | "exact"  | true    |
      | 2       | "is_not" | false   |

  @server
  Scenario Outline: Referenced flag property rules inherit matching without changing flag_evaluates_to
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "source" has a person property condition with operator "exact" and condition value false
    And local feature flag "dependent" has a "flag_evaluates_to" condition requiring flag "source" to evaluate to true
    And local feature flag "variant" evaluates locally to variant "test"
    And local feature flag "variant-dependent" has a "flag_evaluates_to" condition requiring flag "variant" to evaluate to true
    When those flags are evaluated locally with supplied person property value "banana"
    Then local feature flags "source" and "dependent" should both evaluate to <matches>
    And local feature flag "variant-dependent" should evaluate to true
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | matches |
      | omitted | true    |
      | 1       | true    |
      | 2       | false   |

  @server
  Scenario Outline: Supported evaluation surfaces use the same matching snapshot
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK supports <surface>
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "surface-versioned" has a person property condition with operator "exact" and condition value false
    When that flag is evaluated locally through <surface> with supplied property value "banana"
    Then its evaluated flag value should be <matches>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | surface                    | version | matches |
      | the simple single-flag API | omitted | true    |
      | the simple single-flag API | 1       | true    |
      | the simple single-flag API | 2       | false   |
      | the full-result API        | omitted | true    |
      | the full-result API        | 1       | true    |
      | the full-result API        | 2       | false   |
      | the bulk evaluation API    | omitted | true    |
      | the bulk evaluation API    | 1       | true    |
      | the bulk evaluation API    | 2       | false   |
      | the asynchronous wrapper   | omitted | true    |
      | the asynchronous wrapper   | 1       | true    |
      | the asynchronous wrapper   | 2       | false   |
      | the blocking wrapper       | omitted | true    |
      | the blocking wrapper       | 1       | true    |
      | the blocking wrapper       | 2       | false   |

  @server
  Scenario: Concurrent refresh cannot change an in-flight matching snapshot
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" 1
    And a bulk evaluation uses person group recursive-cohort and dependency property conditions comparing false with "banana"
    And the evaluation is paused after capturing its definition snapshot but before evaluating the recursive cohort and dependency
    When otherwise identical definitions with top-level "property_matching_version" 2 are loaded
    And the paused evaluation resumes
    Then every property comparison in that pass should still use legacy matching
    And the next bulk evaluation should use explicit matching without reusing legacy evaluation results
    And no remote feature flag evaluation request should have been sent

  @server
  Scenario: Backward-compatible property matching helpers default to legacy
    Given the SDK exposes a backward-compatible property matching helper without a required version argument
    When the helper compares condition false with present property "banana" using operator "exact" and no version argument
    Then the criterion match result should be true

  @server
  Scenario Outline: Exact compares compact composite JSON representations
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "exact-composite" has an exact person property condition with value <condition>
    When local feature flag "exact-composite" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | version | condition     | property      | matches |
      | omitted | "[1,2]"       | [1,2]         | true    |
      | omitted | [[1,2]]       | [1,2]         | true    |
      | omitted | {"a":2,"b":1} | {"b":1,"a":2} | true    |
      | 1       | "[1,2]"       | [1,2]         | true    |
      | 1       | [[1,2]]       | [1,2]         | true    |
      | 1       | {"a":2,"b":1} | {"b":1,"a":2} | true    |
      | 2       | "[1,2]"       | [1,2]         | true    |
      | 2       | [[1,2]]       | [1,2]         | true    |
      | 2       | {"a":2,"b":1} | {"b":1,"a":2} | true    |

  @server
  Scenario Outline: Exact preserves canonical numeric spellings when the JSON kind survives
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "exact-number" has an exact person property condition with string value <condition>
    When local feature flag "exact-number" is evaluated with numeric property value <property>
    Then the criterion match result should be true

    Examples:
      | condition | property              |
      | "323"     | 323                   |
      | "323.0"   | 323.0                 |
      | "-0.0"    | -0.0                  |
      | "1e-7"    | 0.0000001             |
      | "1e+16"   | 10000000000000000.0   |
      | "0.00001" | 0.00001               |
      | "0.000099" | 0.000099             |

  @server
  Scenario Outline: Exact uses Unicode lowercase without case folding or normalization
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" <version>
    And local feature flag "exact-unicode" has an exact person property condition with value <condition>
    When local feature flag "exact-unicode" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | version | condition | property | matches |
      | omitted | "ä"       | "Ä"      | true    |
      | omitted | "ss"      | "ß"      | false   |
      | omitted | "ς"       | "Σ"      | false   |
      | omitted | "οδος"    | "ΟΔΟΣ"   | true    |
      | omitted | "οδοσ"    | "ΟΔΟΣ"   | false   |
      | omitted | "i̇"      | "İ"      | true    |
      | omitted | "i"       | "İ"      | false   |
      | omitted | "é"       | "É"     | false   |
      | 1       | "ä"       | "Ä"      | true    |
      | 1       | "ss"      | "ß"      | false   |
      | 1       | "ς"       | "Σ"      | false   |
      | 1       | "οδος"    | "ΟΔΟΣ"   | true    |
      | 1       | "οδοσ"    | "ΟΔΟΣ"   | false   |
      | 1       | "i̇"      | "İ"      | true    |
      | 1       | "i"       | "İ"      | false   |
      | 1       | "é"       | "É"     | false   |
      | 2       | "ä"       | "Ä"      | true    |
      | 2       | "ss"      | "ß"      | false   |
      | 2       | "ς"       | "Σ"      | false   |
      | 2       | "οδος"    | "ΟΔΟΣ"   | true    |
      | 2       | "οδοσ"    | "ΟΔΟΣ"   | false   |
      | 2       | "i̇"      | "İ"      | true    |
      | 2       | "i"       | "İ"      | false   |
      | 2       | "é"       | "É"     | false   |

  @server
  Scenario Outline: String criteria use compact stringification and ASCII lowercase
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
      | "icontains_multi"     | [2, {"a":1}]          | "item 2"            | true    |
      | "icontains"           | "[1,2]"               | [1,2]                | true    |

  @server
  Scenario Outline: Non-ASCII case variants do not match ASCII string-search operators
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "ascii-search" has a person property condition with operator <operator> and condition value "ä"
    When local feature flag "ascii-search" is evaluated with supplied property value <property>
    Then the criterion match result should be false

    Examples:
      | operator          | property |
      | "icontains"       | "Äbc"    |
      | "starts_with"     | "Äbc"    |
      | "ends_with"       | "bcÄ"    |
      | "icontains_multi" | "Äbc"    |

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
      | "regex"     | ""               | "admin@example.com" | true    |
      | "not_regex" | ""               | "admin@example.com" | false   |
      | "regex"     | "\\[1,2\\]"     | [1,2]                | true    |

  @server
  Scenario Outline: Unsupported regex execution is inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "regex-limited" uses operator <operator>
    And its pattern uses syntax unsupported by the SDK regex engine
    When local feature flag "regex-limited" is evaluated
    Then local evaluation should be inconclusive
    And neither a negative operator nor cohort negation should turn the failure into a match

    Examples:
      | operator    |
      | "regex"     |
      | "not_regex" |

  @server
  Scenario Outline: Numeric ordering uses complete finite binary64 semantics
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "numeric-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "numeric-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | operator | condition          | property           | result       |
      | "gt"     | "9"                | "10"                | true         |
      | "gte"    | "10"               | "10.0"              | true         |
      | "lt"     | "10"               | 9                   | true         |
      | "lte"    | "10"               | 11                  | false        |
      | "min"    | "10"               | 10                  | true         |
      | "max"    | "10"               | 11                  | false        |
      | "gt"     | "9"                | "10px"              | false        |
      | "gt"     | "9"                | " 10 "              | false        |
      | "gt"     | "9"                | "NaN"               | false        |
      | "lt"     | "9"                | "Infinity"          | false        |
      | "gt"     | " 9 "              | 10                  | inconclusive |


  @server
  Scenario Outline: Dynamic-cohort ranges are inclusive and validate both bounds
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "range-criterion" references a dynamic cohort property condition with operator <operator> and condition value <condition>
    When local feature flag "range-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | operator      | condition        | property       | result       |
      | "between"     | [10, 20]         | 10             | true         |
      | "between"     | ["10", "20"]     | 20             | true         |
      | "between"     | [10, 20]         | 21             | false        |
      | "not_between" | [10, 20]         | 21             | true         |
      | "not_between" | [10, 20]         | "not-a-number" | false        |
      | "not_between" | [10, 20]         | "NaN"          | false        |
      | "between"     | [10, 20]         | "inf"          | false        |
      | "not_between" | [10, 20]         | "inf"          | false        |
      | "between"     | [20, 10]         | 15             | inconclusive |
      | "not_between" | [10]             | 15             | inconclusive |
      | "between"     | ["-inf", "inf"] | 0              | inconclusive |

  @server
  Scenario: Cohort negation does not invert a malformed range
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "range-criterion" references a dynamic cohort leaf with condition "between [1,2,3]"
    And the leaf sets negation to true
    When local feature flag "range-criterion" is evaluated with supplied property value 2
    Then the cohort criterion should be inconclusive
    And negation should not turn it into a match

  @server
  Scenario Outline: Date criteria normalize offsets and preserve strict boundaries
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK clock is fixed at "2025-01-08T00:00:00Z"
    And the effective timezone is "UTC"
    And local feature flag "date-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "date-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | operator          | condition              | property                     | result       |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | "2025-01-01T12:00:00+02:00" | true         |
      | "is_date_after"   | "2025-01-01T10:00:00Z" | "2025-01-01T10:00:01Z"      | true         |
      | "is_date_after"   | "2025-01-01T10:00:00Z" | "2025-01-01T10:00:00Z"      | false        |
      | "is_date_before"  | "2025-01-01T10:00:00Z" | "2025-01-01T09:59:59Z"      | true         |
      | "is_date_exact"   | "2025-01-01T10:00"     | "2025-01-01 10:00:00"       | true         |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | 1735725600                   | true         |
      | "is_date_exact"   | "2025-01-01T10:00:00Z" | "1735725600"                 | true         |
      | "is_date_before"  | "2025-01-01T10:00:00Z" | "not-a-date"                 | false        |
      | "is_date_before"  | "not-a-date"            | "2025-01-01T10:00:00Z"      | inconclusive |

  @server
  Scenario: Naive date criteria use the team timezone
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the effective timezone is "America/Los_Angeles"
    And local feature flag "date-criterion" has an "is_date_after" person property condition with value "2024-06-01"
    When local feature flag "date-criterion" is evaluated with supplied property value "2024-06-01T03:00:00Z"
    Then the criterion match result should be false

  @server
  Scenario Outline: Relative dates use local wall-clock lookbacks
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the effective timezone is "UTC"
    And the SDK clock is fixed at <clock>
    And local feature flag "relative-date-criterion" has an "is_date_exact" person property condition with value <condition>
    When local feature flag "relative-date-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | clock                  | condition | property                | result       |
      | "2025-01-08T00:00:00Z" | "-1h"     | "2025-01-07T23:00:00Z" | true         |
      | "2025-01-08T00:00:00Z" | "1d"      | "2025-01-07T00:00:00Z" | true         |
      | "2025-01-08T00:00:00Z" | "-1w"     | "2025-01-01T00:00:00Z" | true         |
      | "2025-03-31T12:00:00Z" | "2m"      | "2025-01-28T12:00:00Z" | true         |
      | "2025-01-08T00:00:00Z" | "-1y"     | "2024-01-08T00:00:00Z" | true         |
      | "2025-01-08T00:00:00Z" | "10000d"  | "2025-01-01T00:00:00Z" | inconclusive |

  @server
  Scenario Outline: Relative dates define DST overlap and gap behavior
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the effective timezone is "America/Los_Angeles"
    And the SDK clock is fixed at <clock>
    And local feature flag "relative-date-criterion" has an "is_date_exact" person property condition with value <condition>
    When local feature flag "relative-date-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | clock                  | condition | property                | result       |
      | "2024-11-03T10:30:00Z" | "1h"      | "2024-11-03T08:30:00Z" | true         |
      | "2024-03-10T10:30:00Z" | "1h"      | "2024-03-10T09:30:00Z" | inconclusive |

  @server
  Scenario Outline: Direct semantic-version comparison uses normalized total ordering
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "semver-criterion" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "semver-criterion" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | operator     | condition                  | property              | result       |
      | "semver_eq"  | "1.2.0"                    | "v1.02"               | true         |
      | "semver_eq"  | "1.2.0"                    | "v 1.02"              | true         |
      | "semver_eq"  | "1.2.0"                    | " v1.02 "             | false        |
      | "semver_eq"  | "1.2.0"                    | 1.2                   | true         |
      | "semver_neq" | "1.2.0"                    | "1.2.1"               | true         |
      | "semver_gt"  | "1.2.3-beta.1"             | "1.2.3"               | true         |
      | "semver_gte" | "1.2.3"                    | "1.2.3"               | true         |
      | "semver_eq"  | "1.2.3"                    | "1.2.3+build.7"       | false        |
      | "semver_gt"  | "1.2.3+build.1"            | "1.2.3+build.2"       | true         |
      | "semver_lt"  | "2.0.0"                    | "1.9.9"               | true         |
      | "semver_lte" | "1.2.3"                    | "1.2.4"               | false        |
      | "semver_neq" | "1.2.3"                    | "not-a-version"       | false        |
      | "semver_eq"  | "1.2.3"                    | "1.2.3.4"             | false        |
      | "semver_eq"  | "1.2.3-"                   | "1.2.3"               | inconclusive |

  @server
  Scenario Outline: Semantic-version ranges use consistent boundaries
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "semver-range" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "semver-range" is evaluated with supplied property value <property>
    Then the criterion result should be <result>

    Examples:
      | operator           | condition     | property  | result       |
      | "semver_tilde"    | "1.2.3"       | "1.2.9"   | true         |
      | "semver_tilde"    | "1.2.3"       | "1.3.0"   | false        |
      | "semver_tilde"    | "1"           | "1.1.0"   | false        |
      | "semver_caret"    | "1.2.3"       | "1.9.9"   | true         |
      | "semver_caret"    | "1.2.3"       | "2.0.0"   | false        |
      | "semver_caret"    | "0.2.3"       | "0.3.0"   | false        |
      | "semver_caret"    | "0"           | "0.0.1"   | false        |
      | "semver_caret"    | "0.0.0"       | "0.0.1"   | false        |
      | "semver_tilde"    | "1.2.0"       | 1.2       | true         |
      | "semver_tilde"    | "1.2.3+build.7" | "1.2.4+other" | true      |
      | "semver_wildcard" | "1.2.*"       | "1.2.99"  | true         |
      | "semver_wildcard" | "1.2.*"       | "1.3.0"   | false        |
      | "semver_wildcard" | "1.*.*"       | "1.9.0"   | true         |
      | "semver_wildcard" | "1.2"         | "1.9.0"   | true         |
      | "semver_wildcard" | "1.*.3"       | "1.2.3"   | inconclusive |
      | "semver_tilde"    | "not-a-range" | "1.2.3"   | inconclusive |

  @server
  Scenario Outline: Semantic-version ranges apply prerelease admission
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "semver-prerelease" has a person property condition with operator <operator> and condition value <condition>
    When local feature flag "semver-prerelease" is evaluated with supplied property value <property>
    Then the criterion match result should be <matches>

    Examples:
      | operator           | condition          | property           | matches |
      | "semver_tilde"    | "1.2.3"            | "1.2.4-beta.1"     | false   |
      | "semver_caret"    | "1.2.3"            | "1.3.0-beta.1"     | false   |
      | "semver_wildcard" | "1.2.*"            | "1.2.4-beta.1"     | false   |
      | "semver_tilde"    | "1.2.3-beta.1"     | "1.2.3-beta.2"     | true    |
      | "semver_tilde"    | "1.2.3-beta.1"     | "1.2.4-beta.1"     | false   |

  @server
  Scenario Outline: Cohort membership operators compare definitive membership
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "cohort-criterion" references cohort "42" with operator <operator>
    And cohort "42" has definitive local membership result <membership>
    When local feature flag "cohort-criterion" is evaluated locally
    Then the criterion match result should be <matches>

    Examples:
      | operator | membership | matches |
      | omitted  | true       | true    |
      | "in"     | false      | false   |
      | "not_in" | true       | false   |
      | "not_in" | false      | true    |

  @server
  Scenario Outline: Unavailable cohort membership remains inconclusive for both polarities
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "cohort-criterion" references cohort "42" with operator <operator>
    And cohort membership is unavailable because <reason>
    When local feature flag "cohort-criterion" is evaluated locally
    Then the cohort criterion should be inconclusive
    And remote evaluation should remain eligible

    Examples:
      | operator | reason                                        |
      | "in"     | a static cohort has no cached membership      |
      | "not_in" | a static cohort has no cached membership      |
      | "not_in" | the dynamic cohort definition is missing      |
      | "not_in" | the cohort dependency graph contains a cycle |

  @server
  Scenario Outline: Dynamic cohort groups use three-valued composition
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And a dynamic cohort group combines child results <children> with group type <group_type>
    When the group is evaluated locally
    Then the group result should be <result>

    Examples:
      | group_type | children                | result       |
      | "OR"       | true and inconclusive   | true         |
      | "OR"       | false and inconclusive  | inconclusive |
      | "AND"      | false and inconclusive  | false        |
      | "AND"      | true and inconclusive   | inconclusive |
      | "property" | true and true           | true         |
      | "OR"       | no children             | false        |
      | "AND"      | no children             | true         |

  @server
  Scenario: Negation does not turn an inconclusive cohort leaf into a match
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And remote feature flag evaluation is enabled
    And local feature flag "cohort-criterion" references a dynamic cohort with a negated leaf whose required person property is unavailable locally
    When local feature flag "cohort-criterion" is evaluated locally
    Then the cohort criterion should be inconclusive
    And the negation should not turn it into a match
    And remote evaluation should remain eligible

  @server
  Scenario Outline: Malformed cohort structures are inconclusive
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag "cohort-criterion" references a dynamic cohort containing <malformation>
    And its outer cohort operator is "not_in"
    When local feature flag "cohort-criterion" is evaluated
    Then local evaluation should be inconclusive for "cohort-criterion"
    And "not_in" should not turn the failure into a match

    Examples:
      | malformation                               |
      | a known leaf type missing its required key |
      | unknown group type "XOR"                   |

  @server
  Scenario Outline: V2 preserves safe numeric ambiguity fallback
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the loaded definitions response has top-level "property_matching_version" 2
    And the SDK runtime represents source JSON 323 and 323.0 as the same host value
    And the evaluator supports a safe inconclusive result for numeric ambiguity
    And local feature flag "ambiguous-versioned" has a person property condition with operator <operator> and condition value "323.0"
    When that flag is evaluated locally against the collapsed host number
    Then local evaluation should be inconclusive
    And remote evaluation should remain eligible

    Examples:
      | operator |
      | "exact"  |
      | "is_not" |
