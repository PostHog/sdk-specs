## ADDED Requirements

### Requirement: Property matching criteria use a canonical operator inventory and result model

For an ordinary person, person-metadata, or group property criterion, the local evaluator SHALL compare the supplied property value as the left operand with the condition value as the right operand: `property operator condition`. An omitted or null operator SHALL default to `exact`.

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

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. A named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

#### Scenario: Operator omission defaults to exact (@server)
- **GIVEN** a local condition omits its property operator
- **AND** its condition value is `"PRO"`
- **WHEN** it is evaluated against supplied property value `"pro"`
- **THEN** it should match using `exact`

#### Scenario Outline: Unavailable or malformed criteria preserve the correct result state (@server)
- **GIVEN** a local condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated with <property-context>
- **THEN** the criterion result should be <result>
- **AND** another independently evaluable flag should remain eligible for local evaluation

  | operator | condition | property-context | result |
  | `exact` | `"pro"` | the required key omitted | inconclusive |
  | `is_not` | `"pro"` | the required key omitted | inconclusive |
  | `is_not_set` | omitted | the required key omitted from partial local context | inconclusive |
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `10` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |

### Requirement: Exact and is_not compare scalar representations case-insensitively

The `exact` operator SHALL compare non-container JSON values after converting each to its compact scalar string representation and applying at least ASCII case-insensitive comparison. Strings SHALL retain their contents, booleans SHALL use lowercase `true`/`false`, numbers SHALL use a non-locale decimal representation, and JSON null SHALL use `null`. Consequently, string `"1"` SHALL equal numeric `1`, and string `"TRUE"` SHALL equal boolean `true`.

When the condition value is an array, `exact` SHALL match when any array member equals the supplied scalar property under the same comparison. A property-side array or object SHALL NOT be treated as an overlapping set. `is_not` SHALL be the logical complement of the valid `exact` comparison.

#### Scenario Outline: Exact and is_not use canonical coercion and condition-list membership (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `exact` | `"US"` | `"us"` | true |
  | `exact` | `1` | `"1"` | true |
  | `exact` | `true` | `"TRUE"` | true |
  | `exact` | `"null"` | null | true |
  | `exact` | `["US", "CA"]` | `"us"` | true |
  | `exact` | `["US", "CA"]` | `"gb"` | false |
  | `is_not` | `"US"` | `"us"` | false |
  | `is_not` | `["US", "CA"]` | `"gb"` | true |

### Requirement: String criteria use case-insensitive scalar-string comparisons

For `icontains`, `starts_with`, and `ends_with`, the evaluator SHALL convert the supplied property and condition value to their compact scalar string representations, apply at least ASCII case folding, and test whether the property contains, starts with, or ends with the condition value. Their `not_*` forms SHALL negate a valid comparison.

For `icontains_multi`, the condition value SHALL be an array and the criterion SHALL match when the supplied property contains at least one array member under the same case-insensitive scalar-string comparison. `not_icontains_multi` SHALL negate that valid any-member comparison. An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. A non-array multi-contains condition SHALL be malformed and therefore inconclusive.

#### Scenario Outline: String criteria compare the supplied property against the condition value (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `icontains` | `"EXAMPLE"` | `"Admin@example.com"` | true |
  | `not_icontains` | `"EXAMPLE"` | `"Admin@example.com"` | false |
  | `starts_with` | `"ADMIN@"` | `"admin@example.com"` | true |
  | `not_starts_with` | `"USER@"` | `"admin@example.com"` | true |
  | `ends_with` | `".COM"` | `"admin@example.com"` | true |
  | `not_ends_with` | `".ORG"` | `"admin@example.com"` | true |
  | `icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | true |
  | `not_icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | false |
  | `icontains_multi` | `[]` | `"pro account"` | false |
  | `not_icontains_multi` | `[]` | `"pro account"` | true |

### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition value SHALL be a regular-expression pattern and the compact scalar string representation of the supplied property SHALL be the input. Matching SHALL be case-sensitive unless the pattern itself enables case-insensitive behavior, and SHALL search the input rather than adding implicit start/end anchors. `not_regex` SHALL negate a valid search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. A runtime regex resource-limit failure SHALL be inconclusive for the affected flag. Regex compilation or execution MUST NOT throw into application code. Implementations MAY precompile patterns and use platform-appropriate backtracking, size, or execution limits.

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

### Requirement: Numeric criteria parse complete finite numbers and never compare lexicographically

For `gt`, `gte`, `lt`, and `lte`, the evaluator SHALL parse both operands as finite numbers and compare them in `property operator condition` order. JSON numbers and strings whose complete trimmed contents are valid numbers SHALL be accepted. Partial parses such as `"10px"`, non-finite values, null, arrays, and objects SHALL NOT be accepted as numbers. The evaluator MUST NOT fall back to lexicographic comparison.

The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`.

For dynamic-cohort property leaves, `between` SHALL accept exactly two finite numeric bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. `not_between` SHALL negate a valid inclusive range comparison. Missing, nonnumeric, non-finite, reversed, or malformed range operands SHALL NOT match either range operator; a malformed condition range SHALL be locally inconclusive.

#### Scenario Outline: Numeric ordering uses strict numeric semantics (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `gt` | `"9"` | `"10"` | true |
  | `gte` | `10` | `"10.0"` | true |
  | `lt` | `10` | `9` | true |
  | `lte` | `10` | `11` | false |
  | `min` | `10` | `10` | true |
  | `max` | `10` | `11` | false |
  | `gt` | `9` | `"10px"` | false |
  | `gt` | `9` | `"NaN"` | false |
  | `lt` | `9` | `"Infinity"` | false |

#### Scenario Outline: Dynamic-cohort ranges are inclusive and validate both bounds (@server)
- **GIVEN** a dynamic-cohort property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `between` | `[10, 20]` | `10` | true |
  | `between` | `[10, 20]` | `20` | true |
  | `between` | `[10, 20]` | `21` | false |
  | `not_between` | `[10, 20]` | `21` | true |
  | `not_between` | `[10, 20]` | `"not-a-number"` | false |
  | `not_between` | `[10, 20]` | `"NaN"` | false |
  | `between` | `[20, 10]` | `15` | inconclusive |
  | `not_between` | `[10]` | `15` | inconclusive |

### Requirement: Date criteria compare normalized instants

For `is_date_exact`, `is_date_after`, and `is_date_before`, the evaluator SHALL parse the supplied property and condition value as instants and compare them in `property operator condition` order. Exact SHALL require equal instants; before and after SHALL be strict.

An explicit `Z` or numeric offset SHALL be honored. A date-only or naive datetime SHALL use the project/team timezone when that timezone is available to the local evaluator and UTC otherwise. A supplied property MAY represent a Unix timestamp in seconds as a JSON number or complete numeric string.

A relative condition value SHALL consist of an optional leading `-`, an integer from `0` through `9999`, and one lowercase unit: `h`, `d`, `w`, `m`, or `y`. Both the unsigned and minus-prefixed forms SHALL select a lookback from the evaluator's current clock. Hours, days, and weeks SHALL subtract fixed durations; months and years SHALL use calendar-aware subtraction in the effective timezone, preserving the local time and clamping the day to the last valid day of the target month. Acceptance tests SHALL inject a fixed clock.

An invalid property date SHALL be a definitive no-match for every date operator. An invalid condition date SHALL make the criterion inconclusive. Boolean, array, and object values SHALL NOT be interpreted as dates.

#### Scenario Outline: Date criteria normalize offsets and preserve strict boundaries (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** a local property condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T12:00:00+02:00"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:01Z"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:00Z"` | false |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T09:59:59Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00"` | `"2025-01-01T10:00:00Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `1735725600` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"1735725600"` | true |
  | `is_date_after` | `"-7d"` | `"2025-01-02T00:00:00Z"` | true |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"not-a-date"` | false |
  | `is_date_before` | `"not-a-date"` | `"2025-01-01T10:00:00Z"` | inconclusive |

#### Scenario Outline: Relative date criteria use the canonical lookback grammar (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** a local property condition has operator `is_date_exact` and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | condition | property | matches |
  | `"-1h"` | `"2025-01-07T23:00:00Z"` | true |
  | `"1d"` | `"2025-01-07T00:00:00Z"` | true |
  | `"-1w"` | `"2025-01-01T00:00:00Z"` | true |
  | `"1m"` | `"2024-12-08T00:00:00Z"` | true |
  | `"-1y"` | `"2024-01-08T00:00:00Z"` | true |
  | `"10000d"` | `"2025-01-01T00:00:00Z"` | inconclusive |

### Requirement: Semantic-version criteria use canonical SemVer ordering and ranges

For `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, and `semver_lte`, the evaluator SHALL compare the supplied property version with the condition version using Semantic Versioning precedence.

Before parsing, the evaluator SHALL trim surrounding whitespace, remove one lowercase `v` prefix, pad an omitted minor or patch component with zero, and strip leading zeros from all-numeric core components. Prerelease identifiers SHALL participate in standard SemVer precedence. Build metadata SHALL be accepted but SHALL NOT affect equality or ordering.

`semver_tilde`, `semver_caret`, and `semver_wildcard` SHALL define lower-inclusive, upper-exclusive ranges. Tilde SHALL remain within the next minor boundary for a complete version. Caret SHALL remain within the next incompatible major/minor/patch boundary according to the first non-zero component. Wildcards SHALL admit the selected major or major/minor range.

An invalid property version SHALL be a definitive no-match for every semantic-version operator, including `semver_neq`. An invalid condition version or range SHALL make the criterion inconclusive.

#### Scenario Outline: Semantic-version comparison uses normalized SemVer precedence (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_eq` | `"1.2.0"` | `" v1.02 "` | true |
  | `semver_neq` | `"1.2.0"` | `"1.2.1"` | true |
  | `semver_gt` | `"1.2.3-beta.1"` | `"1.2.3"` | true |
  | `semver_gte` | `"1.2.3"` | `"1.2.3+build.7"` | true |
  | `semver_lt` | `"2.0.0"` | `"1.9.9"` | true |
  | `semver_lte` | `"1.2.3"` | `"1.2.4"` | false |
  | `semver_neq` | `"1.2.3"` | `"not-a-version"` | false |
  | `semver_eq` | `"not-a-version"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges are lower-inclusive and upper-exclusive (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_tilde` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.2.9"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.3.0"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_caret` | `"1.2.3"` | `"1.9.9"` | true |
  | `semver_caret` | `"1.2.3"` | `"2.0.0"` | false |
  | `semver_caret` | `"0.2.3"` | `"0.3.0"` | false |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.0"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.99"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.3.0"` | false |
  | `semver_tilde` | `"not-a-range"` | `"1.2.3"` | inconclusive |

### Requirement: Specialized cohort matching preserves scope, recursion, and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match when the referenced cohort membership or locally evaluable dynamic cohort expression matches; `not_in` SHALL negate a definitive membership result. A missing/static cohort definition, recursive cycle, unsupported cohort criterion, or required property unavailable from local context SHALL make the affected flag inconclusive and eligible for remote fallback.

Dynamic cohort property groups SHALL recursively apply their declared `AND` or `OR` composition. A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

#### Scenario Outline: Cohort membership operators compare the referenced membership (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort `42` has local membership result <membership>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion match result should be <matches>

  | operator | membership | matches |
  | omitted | true | true |
  | `in` | false | false |
  | `not_in` | true | false |
  | `not_in` | false | true |

#### Scenario: Negation does not turn an inconclusive cohort leaf into a match (@server)
- **GIVEN** a dynamic cohort contains a negated leaf whose required person property is unavailable locally
- **WHEN** a feature flag depending on that cohort is evaluated locally
- **THEN** the cohort criterion should be inconclusive
- **AND** the negation should not turn it into a match
- **AND** remote evaluation should remain eligible

## MODIFIED Requirements

### Requirement: String prefix/suffix property filter operators

When a local feature-flag definition contains a `starts_with`, `not_starts_with`, `ends_with`, or `not_ends_with` property operator, the local evaluator SHALL apply the canonical string-criterion behavior defined by this spec. Matching SHALL stringify both scalar operands, lowercase them using at least ASCII case-folding, and compare with a prefix check or suffix check, negating only a valid comparison for the `not_*` variants.

At reference commit `935b7683660697bdc75c042c4c56828aeb036754`, these four operators are SDK-local compatibility extensions: they are not members of the Rust feature-flags service's `OperatorType` and are not accepted by the direct feature-flag API allowlist. This requirement therefore defines how an SDK SHALL interpret such an operator if it receives one; it does not claim that the audited server can author or remotely evaluate these operators.

When the property required for evaluation is absent from the supplied partial context, matching SHALL be inconclusive and eligible for remote fallback under the evaluator's ordinary unknown/unsupported-definition behavior.

#### Scenario: A starts_with filter matches locally (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with property "email"
  equal to "Admin@Example.com"
- **THEN** the local evaluation result should be true

#### Scenario: A starts_with filter is inconclusive when the property is missing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with no "email" property
- **THEN** local evaluation should be inconclusive
