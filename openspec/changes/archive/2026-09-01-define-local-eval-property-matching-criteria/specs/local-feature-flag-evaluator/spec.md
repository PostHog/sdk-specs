## ADDED Requirements

### Requirement: Property matching criteria use a canonical operator inventory and result model

For an ordinary person or group property criterion, the local evaluator SHALL compare the supplied property value as the left operand with the condition value as the right operand: `property operator condition`. An omitted or null operator SHALL default to `exact`.

The canonical operator inventory SHALL be scoped as follows:

| Scope | Operators |
| --- | --- |
| Ordinary property equality and presence | `exact`, `is_not`, `is_set`, `is_not_set` |
| Ordinary property strings | `icontains`, `not_icontains`, `icontains_multi`, `not_icontains_multi`, `starts_with`, `not_starts_with`, `ends_with`, `not_ends_with`, `regex`, `not_regex` |
| Ordinary property numeric ordering | `gt`, `gte`, `lt`, `lte`; legacy aliases `min` and `max` normalize to `gte` and `lte` |
| Ordinary property dates | `is_date_exact`, `is_date_after`, `is_date_before` |
| Ordinary property semantic versions | `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, `semver_lte`, `semver_tilde`, `semver_caret`, `semver_wildcard` |
| Dynamic-cohort property leaves only | `between`, `not_between` |
| Cohort membership only | `in`, `not_in` |
| Flag dependency only | `flag_evaluates_to` |

The existing presence-operator requirement SHALL govern `is_set` and `is_not_set`, and the existing dependency-filter requirement SHALL govern `flag_evaluates_to`.

Because caller-supplied local property maps are partial context, an absent required property key SHALL make that criterion inconclusive for every ordinary property operator, including named negative operators. A value-requiring operator whose condition value is omitted SHALL be inconclusive. An operator that is unknown or invalid for the criterion type SHALL be inconclusive for only the affected flag.

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. A malformed condition value SHALL be inconclusive unless an operator-family requirement explicitly defines a safe result. A named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

#### Scenario Outline: Omitted and null operators default to exact (@server)
- **GIVEN** a local condition uses <operator-state> for its property operator
- **AND** its condition value is `"PRO"`
- **WHEN** it is evaluated against supplied property value `"pro"`
- **THEN** it should match using `exact`

  | operator-state |
  | an omitted operator |
  | an explicit JSON null operator |

#### Scenario Outline: Unavailable or malformed criteria preserve the correct result state (@server)
- **GIVEN** a local condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated with <property-context>
- **THEN** the criterion result should be <result>

  | operator | condition | property-context | result |
  | `exact` | `"pro"` | the required key omitted | inconclusive |
  | `is_not` | `"pro"` | the required key omitted | inconclusive |
  | `is_not_set` | omitted | the required key omitted from partial local context | inconclusive |
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `"10"` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |
### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition SHALL be a string pattern. The evaluator SHALL stringify the supplied property using the compact JSON rules defined for equality. Matching SHALL be case-sensitive unless the pattern enables case-insensitive behavior, and SHALL search the input without adding implicit anchors. An empty pattern therefore matches every present property value. `not_regex` SHALL negate only a successfully compiled and executed search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. Syntax unsupported by an SDK's regex engine, or a regex execution failure, SHALL be inconclusive for that flag and MUST NOT become a match through `not_regex` or cohort negation. Regex matching MUST NOT throw into application code.

Portable acceptance vectors SHALL use syntax shared by the target SDK engines. Engine-specific constructs require remote fallback when the SDK cannot evaluate them.

#### Scenario Outline: Regex criteria search safely without implicit flags or anchors (@server)
- **GIVEN** a local property condition with operator <operator> and pattern <pattern>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | pattern | property | matches |
  | `regex` | `"example\\.com"` | `"admin@example.com"` | true |
  | `regex` | `"^example"` | `"admin@example.com"` | false |
  | `regex` | `"EXAMPLE"` | `"admin@example.com"` | false |
  | `not_regex` | `"example\\.org"` | `"admin@example.com"` | true |
  | `regex` | `"["` | `"admin@example.com"` | false |
  | `not_regex` | `"["` | `"admin@example.com"` | false |
  | `regex` | `""` | `"admin@example.com"` | true |
  | `not_regex` | `""` | `"admin@example.com"` | false |
  | `regex` | `"\\[1,2\\]"` | `[1,2]` | true |

#### Scenario: Unsupported regex execution is inconclusive (@server)
- **GIVEN** a pattern uses syntax unsupported by the SDK regex engine
- **WHEN** the pattern is evaluated with `regex` or `not_regex`
- **THEN** local evaluation should be inconclusive for that flag
- **AND** neither a negative operator nor cohort negation should turn the failure into a match
### Requirement: Numeric criteria use complete finite binary64 comparisons

For `gt`, `gte`, `lt`, and `lte`, the condition SHALL be a string matching the complete decimal grammar `[+-]?(digits[.digits*]?|.digits+)([eE][+-]?digits+)?`, where `digits` means one or more ASCII decimal digits and `digits*` means zero or more. The supplied property MAY be a JSON number or a string matching the same grammar. The evaluator SHALL convert both operands to finite IEEE-754 binary64 values and compare them in `property operator condition` order. No whitespace is trimmed. Partial parses such as `"10px"`, padded strings such as `" 10 "`, non-finite values, null, booleans, arrays, and objects SHALL NOT be accepted. The evaluator MUST NOT fall back to lexicographic or arbitrary-precision decimal comparison.

The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`.

A present property that cannot be converted to a finite number SHALL be a definitive no-match. An invalid condition number SHALL be inconclusive. Binary64 rounding is observable for values that cannot be represented exactly.

For dynamic-cohort property leaves, `between` SHALL accept exactly two finite numeric or numeric-string bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. `not_between` SHALL negate only a valid inclusive range comparison. Missing, nonnumeric, non-finite, reversed, or malformed ranges SHALL NOT match either range operator; a malformed condition range SHALL be inconclusive before applying any cohort leaf `negation`.

#### Scenario Outline: Numeric ordering uses complete finite binary64 semantics (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `gt` | `"9"` | `"10"` | true |
  | `gte` | `"10"` | `"10.0"` | true |
  | `lt` | `"10"` | `9` | true |
  | `lte` | `"10"` | `11` | false |
  | `min` | `"10"` | `10` | true |
  | `max` | `"10"` | `11` | false |
  | `gt` | `"9"` | `"10px"` | false |
  | `gt` | `"9"` | `" 10 "` | false |
  | `gt` | `"9"` | `"NaN"` | false |
  | `lt` | `"9"` | `"Infinity"` | false |
  | `gt` | `" 9 "` | `10` | inconclusive |

#### Scenario Outline: Dynamic-cohort ranges are inclusive and validate both bounds (@server)
- **GIVEN** a dynamic-cohort property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `between` | `[10, 20]` | `10` | true |
  | `between` | `["10", "20"]` | `20` | true |
  | `between` | `[10, 20]` | `21` | false |
  | `not_between` | `[10, 20]` | `21` | true |
  | `not_between` | `[10, 20]` | `"not-a-number"` | false |
  | `not_between` | `[10, 20]` | `"NaN"` | false |
  | `between` | `[10, 20]` | `"inf"` | false |
  | `not_between` | `[10, 20]` | `"inf"` | false |
  | `between` | `[20, 10]` | `15` | inconclusive |
  | `not_between` | `[10]` | `15` | inconclusive |
  | `between` | `["-inf", "inf"]` | `0` | inconclusive |

#### Scenario: Cohort negation does not invert a malformed range (@server)
- **GIVEN** a dynamic cohort leaf has condition `between [1,2,3]`
- **AND** the leaf sets `negation` to true
- **WHEN** it is evaluated against property `2`
- **THEN** the cohort leaf should be inconclusive
- **AND** negation should not turn it into a match
### Requirement: Date criteria compare normalized instants in the effective timezone

For `is_date_exact`, `is_date_after`, and `is_date_before`, the evaluator SHALL parse the supplied property and condition as instants and compare them in `property operator condition` order. Exact SHALL require equal instants; before and after SHALL be strict.

The portable absolute-date grammar SHALL include RFC 3339 values with `Z` or a numeric offset, `YYYY-MM-DD`, and naive `YYYY-MM-DD[ T]HH:MM[:SS[.fraction]]`. Explicit offsets SHALL be honored. Date-only and naive values SHALL use the project/team timezone when available to the evaluator and UTC otherwise. An implementation accepting an additional naive format SHALL interpret it in the effective timezone rather than silently using UTC.

A property MAY represent integral Unix seconds as a finite JSON integer or complete unpadded integer string. Fractional and non-finite values, booleans, arrays, and objects are outside this contract and SHALL NOT be interpreted as dates.

A relative condition SHALL consist of an optional leading `-`, an integer from `0` through `9999`, and one lowercase unit: `h`, `d`, `w`, `m`, or `y`. Both unsigned and minus-prefixed forms select a lookback. The evaluator SHALL convert its current instant to the effective timezone, subtract on the naive local wall clock, and convert the result back to an instant. Hours, days, and weeks therefore preserve wall-clock subtraction across offset changes rather than guaranteeing a fixed elapsed duration.

On a fall-back overlap, the evaluator SHALL choose the earlier of the two matching instants. If subtraction or naive parsing lands in a spring-forward gap, the criterion SHALL be inconclusive. Month and year lookbacks SHALL subtract one unit at a time, preserving the current local time and clamping after every step. Consequently, a two-month lookback from March 31 can retain February's clamped day in January. Acceptance tests SHALL inject both a fixed clock and an effective timezone.

A present property that is outside the accepted grammar SHALL be a definitive no-match. An omitted, non-string, invalid, or locally uninterpretable condition SHALL be inconclusive.

#### Scenario Outline: Date criteria normalize offsets and preserve strict boundaries (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** the effective timezone is `UTC`
- **AND** a local property condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T12:00:00+02:00"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:01Z"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:00Z"` | false |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T09:59:59Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00"` | `"2025-01-01 10:00:00"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `1735725600` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"1735725600"` | true |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"not-a-date"` | false |
  | `is_date_before` | `"not-a-date"` | `"2025-01-01T10:00:00Z"` | inconclusive |

#### Scenario: Naive dates use the team timezone (@server)
- **GIVEN** the effective timezone is `America/Los_Angeles`
- **AND** an `is_date_after` condition has value `"2024-06-01"`
- **WHEN** it is evaluated against property `"2024-06-01T03:00:00Z"`
- **THEN** the criterion should not match

#### Scenario Outline: Relative dates use local wall-clock lookbacks (@server)
- **GIVEN** the effective timezone is `UTC`
- **AND** the local evaluator clock is fixed at <clock>
- **AND** an `is_date_exact` condition has value <condition>
- **WHEN** it is evaluated against property <property>
- **THEN** the criterion result should be <result>

  | clock | condition | property | result |
  | `2025-01-08T00:00:00Z` | `"-1h"` | `"2025-01-07T23:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"1d"` | `"2025-01-07T00:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"-1w"` | `"2025-01-01T00:00:00Z"` | true |
  | `2025-03-31T12:00:00Z` | `"2m"` | `"2025-01-28T12:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"-1y"` | `"2024-01-08T00:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"10000d"` | `"2025-01-01T00:00:00Z"` | inconclusive |

#### Scenario Outline: Relative dates define DST overlap and gap behavior (@server)
- **GIVEN** the effective timezone is `America/Los_Angeles`
- **AND** the local evaluator clock is fixed at <clock>
- **AND** an `is_date_exact` condition has value <condition>
- **WHEN** it is evaluated against property <property>
- **THEN** the criterion result should be <result>

  | clock | condition | property | result |
  | `2024-11-03T10:30:00Z` | `"1h"` | `"2024-11-03T08:30:00Z"` | true |
  | `2024-03-10T10:30:00Z` | `"1h"` | `"2024-03-10T09:30:00Z"` | inconclusive |
### Requirement: Semantic-version criteria use consistent normalization and range matching

For direct `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, and `semver_lte`, the evaluator SHALL stringify each JSON operand, remove one lowercase `v` prefix only when it is the first character, then trim surrounding whitespace. It SHALL pad an omitted minor or patch component with zero and strip leading zeros from all-numeric core components before parsing. Thus `v1.02`, `v 1.02`, and ` 1.02 ` normalize to `1.2.0`, while ` v1.02 ` is invalid because prefix removal occurs before trimming. JSON numeric properties such as `1` and `1.2` are runtime-compatible and normalize to `1.0.0` and `1.2.0`.

Core components SHALL be unsigned 64-bit integers. More than three core components, an empty prerelease suffix such as `1.2.3-`, and other invalid SemVer syntax SHALL be rejected. Prerelease identifiers SHALL use standard SemVer precedence. Direct equality SHALL distinguish versions whose build metadata differs. Direct ordering SHALL compare dot-separated build identifiers lexicographically, comparing numeric identifiers numerically and sorting them before nonnumeric identifiers. Range matching SHALL ignore build metadata.

For `semver_tilde` and `semver_caret`, the evaluator SHALL normalize and pad the condition to a complete version before applying the corresponding range. Consequently `~1` behaves as `~1.0.0`, and `^0` behaves as `^0.0.0`. For `semver_wildcard`, it SHALL strip leading zeros from numeric components without padding and accept `*`, `x`, or `X` as wildcard tokens. Supported spellings include `*`, `x`, `X`, `1.*`, `1.*.*`, and `1.2.*`; an interior wildcard such as `1.*.3` is invalid. A condition without a wildcard token, such as `1.2`, uses caret semantics.

A prerelease property SHALL satisfy a range only when the range contains a prerelease comparator with the same major, minor, and patch tuple. An invalid property version SHALL be a definitive no-match for every semantic-version operator, including `semver_neq`; an omitted or invalid condition version or range SHALL be inconclusive.

#### Scenario Outline: Direct semantic-version comparison uses normalized total ordering (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `semver_eq` | `"1.2.0"` | `"v1.02"` | true |
  | `semver_eq` | `"1.2.0"` | `"v 1.02"` | true |
  | `semver_eq` | `"1.2.0"` | `" v1.02 "` | false |
  | `semver_eq` | `"1.2.0"` | `1.2` | true |
  | `semver_neq` | `"1.2.0"` | `"1.2.1"` | true |
  | `semver_gt` | `"1.2.3-beta.1"` | `"1.2.3"` | true |
  | `semver_gte` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_eq` | `"1.2.3"` | `"1.2.3+build.7"` | false |
  | `semver_gt` | `"1.2.3+build.1"` | `"1.2.3+build.2"` | true |
  | `semver_lt` | `"2.0.0"` | `"1.9.9"` | true |
  | `semver_lte` | `"1.2.3"` | `"1.2.4"` | false |
  | `semver_neq` | `"1.2.3"` | `"not-a-version"` | false |
  | `semver_eq` | `"1.2.3"` | `"1.2.3.4"` | false |
  | `semver_eq` | `"1.2.3-"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges use consistent boundaries (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `semver_tilde` | `"1.2.3"` | `"1.2.9"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.3.0"` | false |
  | `semver_tilde` | `"1"` | `"1.1.0"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.9.9"` | true |
  | `semver_caret` | `"1.2.3"` | `"2.0.0"` | false |
  | `semver_caret` | `"0.2.3"` | `"0.3.0"` | false |
  | `semver_caret` | `"0"` | `"0.0.1"` | false |
  | `semver_caret` | `"0.0.0"` | `"0.0.1"` | false |
  | `semver_tilde` | `"1.2.0"` | `1.2` | true |
  | `semver_tilde` | `"1.2.3+build.7"` | `"1.2.4+other"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.99"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.3.0"` | false |
  | `semver_wildcard` | `"1.*.*"` | `"1.9.0"` | true |
  | `semver_wildcard` | `"1.2"` | `"1.9.0"` | true |
  | `semver_wildcard` | `"1.*.3"` | `"1.2.3"` | inconclusive |
  | `semver_tilde` | `"not-a-range"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges apply prerelease admission (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_tilde` | `"1.2.3"` | `"1.2.4-beta.1"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.3.0-beta.1"` | false |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.4-beta.1"` | false |
  | `semver_tilde` | `"1.2.3-beta.1"` | `"1.2.3-beta.2"` | true |
  | `semver_tilde` | `"1.2.3-beta.1"` | `"1.2.4-beta.1"` | false |
### Requirement: Specialized cohort matching preserves scope and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match a definitive referenced membership result; `not_in` SHALL negate only a definitive result. A static cohort with cached local membership is therefore conclusive. A static cohort definition without membership data, a missing dynamic definition, a dependency cycle, or unavailable required context SHALL be inconclusive and MUST NOT be represented as membership false merely to evaluate `not_in`.

Dynamic cohort groups SHALL recursively apply three-valued composition. `OR` returns true when any child is true, false when every child is false, and inconclusive otherwise. `AND` and its legacy wire alias `property` return false when any child is false, true when every child is true, and inconclusive otherwise. An empty `OR` is false; an empty `AND` or `property` group is true.

A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. Unsupported or malformed cohort criteria SHALL be inconclusive and MUST NOT throw into application code. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

Implementations SHALL detect cohort cycles and bound recursion. A definition beyond an implementation's safe recursion bound MAY become inconclusive, but MUST NOT be silently truncated or crash application code.

#### Scenario Outline: Cohort membership operators compare definitive membership (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort `42` has a definitive local membership result <membership>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion match result should be <matches>

  | operator | membership | matches |
  | omitted | true | true |
  | `in` | false | false |
  | `not_in` | true | false |
  | `not_in` | false | true |

#### Scenario Outline: Unavailable membership remains inconclusive for both polarities (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort membership is unavailable because <reason>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion should be inconclusive
- **AND** remote evaluation should remain eligible

  | operator | reason |
  | `in` | the static cohort has no cached membership |
  | `not_in` | the static cohort has no cached membership |
  | `not_in` | the dynamic cohort definition is missing |
  | `not_in` | the cohort dependency graph contains a cycle |

#### Scenario Outline: Dynamic cohort groups use three-valued composition (@server)
- **GIVEN** a dynamic cohort group combines child results <children> with group type <group-type>
- **WHEN** the group is evaluated locally
- **THEN** the group result should be <result>

  | group-type | children | result |
  | `OR` | true and inconclusive | true |
  | `OR` | false and inconclusive | inconclusive |
  | `AND` | false and inconclusive | false |
  | `AND` | true and inconclusive | inconclusive |
  | `property` | true and true | true |
  | `OR` | no children | false |
  | `AND` | no children | true |

#### Scenario: Negation does not turn an inconclusive cohort leaf into a match (@server)
- **GIVEN** a dynamic cohort contains a negated leaf whose required person property is unavailable locally
- **WHEN** a feature flag depending on that cohort is evaluated locally
- **THEN** the cohort criterion should be inconclusive
- **AND** the negation should not turn it into a match
- **AND** remote evaluation should remain eligible

#### Scenario Outline: Malformed cohort structures are inconclusive (@server)
- **GIVEN** a referenced dynamic cohort contains <malformation>
- **AND** the outer membership operator is `not_in`
- **WHEN** the cohort condition is evaluated locally
- **THEN** the cohort condition should be inconclusive
- **AND** `not_in` should not turn the failure into a match

  | malformation |
  | a known leaf type missing its required key |
  | unknown group type `XOR` |


### Requirement: Multi-contains string search uses ANY semantics

The local evaluator SHALL implement `icontains_multi` and `not_icontains_multi` with an array condition. It SHALL stringify the supplied property and each condition member with the backend-compatible representation, lowercase only ASCII characters `A` through `Z`, and compare each member as a substring. `icontains_multi` SHALL match when ANY member matches. `not_icontains_multi` SHALL be the logical inverse for a present, supported property value.

An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. When the required property key is absent from caller-supplied local evaluation context, both operators SHALL remain inconclusive and eligible for remote fallback.

#### Scenario Outline: Multi-contains evaluates each condition value

- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | true |
  | `not_icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | false |
  | `icontains_multi` | `[]` | `"pro account"` | false |
  | `not_icontains_multi` | `[]` | `"pro account"` | true |
  | `icontains_multi` | `[2, {"a":1}]` | `"item 2"` | true |
