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

Direct API authoring rules and evaluator compatibility are intentionally distinct. With structural and cross-field enforcement enabled, the current authoring surface excludes `person_metadata`, `between`, and `not_between`; canonicalizes `min`/`max`; requires strings for ordinary numeric ordering, single-value string search, regex, and SemVer conditions; requires an array for multi-contains; and rejects mixed person/group filters. The runtime matcher accepts additional forms identified below. An SDK SHALL implement those runtime-compatible forms when received and SHALL NOT reject a whole definition payload merely because a condition could not be authored under the enforced API rules.

A `person_metadata` filter is runtime-compatible only when its named metadata field is supplied through dedicated person-metadata context. It MUST NOT read a same-named user property. If the metadata field is unavailable, the criterion is inconclusive. The currently defined metadata field is `created_at`.

Because caller-supplied local property maps are partial context, an absent required property key SHALL make that criterion inconclusive for every ordinary property operator, including named negative operators. A value-requiring operator whose condition value is omitted SHALL be inconclusive. An operator that is unknown or invalid for the criterion type SHALL be inconclusive for only the affected flag. These are deliberate SDK fallback rules even where the released backend runtime fails closed after receiving a malformed definition.

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
- **AND** another independently evaluable flag should remain eligible for local evaluation

  | operator | condition | property-context | result |
  | `exact` | `"pro"` | the required key omitted | inconclusive |
  | `is_not` | `"pro"` | the required key omitted | inconclusive |
  | `is_not_set` | omitted | the required key omitted from partial local context | inconclusive |
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `10` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |
### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the evaluator SHALL stringify both the condition pattern and supplied property using the compact JSON rules defined for equality. The direct authoring API requires a string pattern; stringification of another JSON condition type is runtime compatibility for legacy or injected definitions. Matching SHALL be case-sensitive unless the pattern itself enables case-insensitive behavior, and SHALL search the input without adding implicit anchors. An empty pattern therefore matches every present property value. `not_regex` SHALL negate only a successfully compiled and executed search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. A pattern accepted by the flags service but unsupported by an SDK's regex dialect SHALL be inconclusive for that flag. Runtime backtracking, size, recursion, timeout, or other resource-limit failures SHALL also be inconclusive and MUST NOT become matches through `not_regex` or a cohort leaf's `negation` field. This deliberately preserves SDK fallback where the released backend matcher can collapse a regex execution error to false. Regex compilation or execution MUST NOT throw into application code. Implementations MAY precompile patterns and use platform-appropriate resource controls.

Portable acceptance vectors SHALL use syntax shared by the target SDK engines. Backreferences, lookaround, and other engine-specific constructs are not required to produce a local boolean when the SDK engine cannot implement them; they require remote fallback instead.

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
  | `regex` | `123` | `"x123x"` | true |

#### Scenario: Unsupported or resource-limited regex execution is inconclusive (@server)
- **GIVEN** a pattern is valid for remote feature-flag evaluation but unsupported by the SDK regex engine, or exceeds the SDK's regex resource limit
- **WHEN** the pattern is evaluated with `regex` or `not_regex`
- **THEN** local evaluation should be inconclusive for that flag
- **AND** no negative operator or cohort leaf negation should turn the failure into a match
- **AND** independent flags should remain locally evaluable
### Requirement: Numeric criteria use complete finite binary64 comparisons

For `gt`, `gte`, `lt`, and `lte`, the evaluator SHALL convert both operands to finite IEEE-754 binary64 values and compare them in `property operator condition` order. Runtime-compatible operands are JSON numbers or strings matching the complete decimal grammar `[+-]?(digits[.digits*]?|.digits+)([eE][+-]?digits+)?`, where `digits` means one or more ASCII decimal digits and `digits*` means zero or more. No whitespace is trimmed. Partial parses such as `"10px"`, padded strings such as `" 10 "`, non-finite values, null, booleans, arrays, and objects SHALL NOT be accepted. The evaluator MUST NOT fall back to lexicographic or arbitrary-precision decimal comparison.

The direct authoring API requires condition-side strings for these operators, but the runtime evaluator SHALL also accept a JSON-number condition from a legacy or injected definition. The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`; direct API writes normalize those aliases to their canonical names.

A present property that cannot be converted to a finite number SHALL be a definitive no-match. An invalid condition number SHALL be inconclusive. Binary64 rounding is observable: integers above `2^53` can collapse, tiny exponents can underflow to zero, and values that overflow to infinity are invalid rather than comparable. The finite-only rule deliberately rejects infinities that the released runtime's raw `f64` path can sometimes compare.

For dynamic-cohort property leaves, `between` SHALL accept exactly two finite numeric or numeric-string bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. `not_between` SHALL negate only a valid inclusive range comparison. Missing, nonnumeric, non-finite, reversed, or malformed ranges SHALL NOT match either range operator; a malformed condition range SHALL be inconclusive before applying any cohort leaf `negation`.

#### Scenario Outline: Numeric ordering uses complete finite binary64 semantics (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `gt` | `"9"` | `"10"` | true |
  | `gte` | `10` | `"10.0"` | true |
  | `lt` | `10` | `9` | true |
  | `lte` | `10` | `11` | false |
  | `min` | `10` | `10` | true |
  | `max` | `10` | `11` | false |
  | `gt` | `9` | `"10px"` | false |
  | `gt` | `9` | `" 10 "` | false |
  | `gt` | `9` | `"NaN"` | false |
  | `lt` | `9` | `"Infinity"` | false |
  | `gt` | `" 9 "` | `10` | inconclusive |
  | `gt` | `"1e400"` | `10` | inconclusive |
  | `gt` | `"9007199254740992"` | `9007199254740993` | false |
  | `gt` | `0` | `"1e-400"` | false |

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

The portable absolute-date grammar SHALL include RFC 3339 values with `Z` or a numeric offset, `YYYY-MM-DD`, and naive `YYYY-MM-DD[ T]HH:MM[:SS[.fraction]]`. Explicit offsets SHALL be honored. Date-only and naive values SHALL use the project/team timezone when available to the evaluator and UTC otherwise. Other backend-accepted best-effort date strings MAY be evaluated locally only when their interpretation is unambiguous and agrees with remote evaluation; otherwise they require fallback. An implementation accepting an additional naive format SHALL interpret it in the effective timezone rather than silently using UTC.

A property MAY represent Unix seconds as a JSON number or complete unpadded numeric string, including fractional seconds. Conversion SHALL use finite binary64 input rounded to the nearest nanosecond and SHALL mathematically normalize negative fractions across the Unix epoch. This deliberately differs from the released backend's float-to-integer edge behavior for negative fractions. Non-finite strings such as `NaN` and `Infinity` are invalid dates and MUST NOT be coerced to the epoch, even though the released backend can currently coerce `NaN` to the Unix epoch. Booleans, arrays, and objects SHALL NOT be interpreted as dates.

A relative condition SHALL consist of an optional leading `-`, an integer from `0` through `9999`, and one lowercase unit: `h`, `d`, `w`, `m`, or `y`. Both unsigned and minus-prefixed forms select a lookback. The evaluator SHALL convert its current instant to the effective timezone, subtract on the naive local wall clock, and convert the result back to an instant. Hours, days, and weeks therefore preserve wall-clock subtraction across offset changes rather than guaranteeing a fixed elapsed duration.

On a fall-back overlap, the evaluator SHALL choose the earlier of the two matching instants. If subtraction or naive parsing lands in a spring-forward gap, the criterion SHALL be inconclusive. Month and year lookbacks SHALL subtract one unit at a time, preserving the current local time and clamping after every step. Consequently, a two-month lookback from March 31 can retain February's clamped day in January. Acceptance tests SHALL inject both a fixed clock and an effective timezone.

A present property that is outside the accepted grammar SHALL be a definitive no-match. An omitted, non-string, invalid, or locally uninterpretable condition SHALL be inconclusive even though the released backend can fail closed for such malformed definitions.

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
  | `is_date_exact` | `"1970-01-01T00:00:00Z"` | `"NaN"` | false |
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

#### Scenario: Binary64 fractional Unix seconds round to nanoseconds (@server)
- **GIVEN** an `is_date_exact` condition has value `"2028-03-10T05:09:07.867530107Z"`
- **WHEN** it is evaluated against Unix-second property `1836277747.86753`
- **THEN** the criterion should match

#### Scenario: Pre-epoch fractional Unix seconds normalize mathematically (@server)
- **GIVEN** an `is_date_exact` condition has value `"1969-12-31T23:59:59.500000000Z"`
- **WHEN** it is evaluated against Unix-second property `-0.5`
- **THEN** the criterion should match
### Requirement: Semantic-version criteria reproduce the flags service's parser and range model

For direct `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, and `semver_lte`, the evaluator SHALL stringify each JSON operand, remove one lowercase `v` prefix only when it is the first character, then trim surrounding whitespace. It SHALL pad an omitted minor or patch component with zero and strip leading zeros from all-numeric core components before parsing. Thus `v1.02`, `v 1.02`, and ` 1.02 ` normalize to `1.2.0`, while ` v1.02 ` is invalid because prefix removal occurs before trimming. JSON numeric properties such as `1` and `1.2` are runtime-compatible and normalize to `1.0.0` and `1.2.0`.

Core components SHALL be unsigned 64-bit integers. More than three core components, an empty prerelease suffix such as `1.2.3-`, and other invalid SemVer syntax SHALL be rejected. Prerelease identifiers SHALL use standard SemVer precedence. Direct comparisons SHALL use the `semver` crate's total `Version` ordering, including build metadata: direct equality distinguishes versions whose build metadata differs, and ordering compares dot-separated build identifiers lexicographically, numeric identifiers numerically, and numeric identifiers before nonnumeric identifiers. This differs from SemVer precedence and from range matching, both of which ignore build metadata.

For `semver_tilde` and `semver_caret`, the evaluator SHALL normalize and pad the condition to a complete version before constructing a `VersionReq`. Consequently `~1` behaves as `~1.0.0`, and `^0` behaves as `^0.0.0`. For `semver_wildcard`, it SHALL strip leading zeros from numeric components without padding, replace `*` tokens with `x`, and parse the result as a `VersionReq`. Runtime-compatible wildcard spellings include `*`, `x`, `X`, `1.*`, `1.*.*`, and `1.2.*`; an interior wildcard such as `1.*.3` is invalid. A condition without a wildcard token, such as `1.2`, is parsed by `VersionReq` using its default caret semantics. A shape such as `1.2.3.*` is invalid at runtime even though staged API validation can accept it.

Every range operator SHALL use `VersionReq::matches`, not only a numeric half-open interval. Build metadata is ignored. A prerelease property satisfies a requirement only when at least one comparator contains a prerelease with the same major, minor, and patch tuple. Stable versions otherwise follow the corresponding tilde, caret, or wildcard boundaries.

The direct authoring API requires SemVer conditions to be strings and uses a different validator from the runtime parser. Runtime-compatible prefixes, build metadata, `x`/`X`, bare `*`, and numeric conditions can therefore differ from enforced authoring validity. SDKs SHALL apply the runtime rules above to any received definition. An invalid property version SHALL be a definitive no-match for every semantic-version operator, including `semver_neq`; an omitted or invalid condition version or requirement SHALL be inconclusive.

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
  | `semver_eq` | `"18446744073709551616.0.0"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges use VersionReq matching (@server)
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
  | `semver_wildcard` | `"1.2.3.*"` | `"1.2.3"` | inconclusive |
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
### Requirement: Specialized cohort matching preserves scope, recursion, and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match a definitive referenced membership result; `not_in` SHALL negate only a definitive result. A static cohort with cached local membership is therefore conclusive. A static cohort definition without membership data, a missing dynamic definition, a dependency cycle, or unavailable required context SHALL be inconclusive and MUST NOT be represented as membership false merely to evaluate `not_in`.

Dynamic cohort groups SHALL recursively apply three-valued composition. `OR` returns true when any child is true, false when every child is false, and inconclusive otherwise. `AND` and its legacy wire alias `property` return false when any child is false, true when every child is true, and inconclusive otherwise. An empty `OR` is false; an empty `AND` or `property` group is true.

A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. This deliberately differs from the released dynamic-cohort path, which can collapse a matcher error to false before applying leaf negation. Unsupported behavioral leaf types, malformed known leaves, missing required leaf fields, unknown group combinators, invalid matcher operands, and cohort parsing failures SHALL be inconclusive for only the affected flag. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

Implementations SHALL detect cohort cycles and bound recursion. They MUST support at least 64 nested group levels. A deeper definition MAY become inconclusive for its flag, but MUST NOT be silently truncated, overflow the stack, crash application code, or interrupt independent flag evaluation.

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

#### Scenario Outline: Malformed cohort structures are isolated to their flag (@server)
- **GIVEN** a referenced dynamic cohort contains <malformation>
- **AND** the outer membership operator is `not_in`
- **WHEN** the flag and an independent rollout-only flag are evaluated locally
- **THEN** the cohort flag should be inconclusive
- **AND** the independent flag should still return its local result

  | malformation |
  | a known leaf type missing its required key |
  | unknown group type `XOR` |
  | a definition deeper than the implementation's supported bound |

## MODIFIED Requirements

### Requirement: Backend-compatible property-filter stringification

The local evaluator SHALL stringify operands before applying the `exact`, `is_not`, `icontains`, `not_icontains`, `icontains_multi`, `not_icontains_multi`, `starts_with`,
`not_starts_with`, `ends_with`, or `not_ends_with` operator, using the same canonical representation as the flags service. A JSON string SHALL contribute its unquoted contents. Every other JSON value SHALL use the canonical output of Rust `serde_json::Value::to_string()`.

The canonical representation SHALL use lowercase JSON booleans and null, compact arrays without optional whitespace, and compact objects whose keys are recursively sorted lexicographically. Numbers SHALL use `serde_json`'s canonical finite-number spelling. This includes preserving the integer-versus-floating-point distinction when the runtime retains it, preserving negative zero for a floating-point value, and using the same plain-decimal and exponent cutovers as the flags service. The boolean-filter and filter-array precedence specified below SHALL run before treating a filter array as one string value.

When a host runtime irreversibly collapses distinct JSON values before local evaluation receives them, such as integer `323` and floating-point `323.0`, the SDK MUST NOT invent the discarded numeric kind. An evaluator with a dedicated inconclusive result SHOULD use it for an ambiguous `exact` or `is_not` comparison so remote evaluation remains eligible. Otherwise the SDK SHALL use one deterministic, locale-independent representation and document the limitation.

#### Scenario: Integer and preserved floating-point values remain distinct

- **WHEN** an `exact` filter with string value `"323"` is evaluated against JSON integer property `323`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with string value `"323.0"` is evaluated against a distinctly represented JSON floating-point property `323.0`
- **THEN** the local evaluation result should be true
- **AND** an `exact` filter with string value `"323"` should not match that floating-point property

#### Scenario: Composite values use compact sorted JSON

- **WHEN** an `exact` filter with string value `"[1,2]"` is evaluated against array property `[1, 2]`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with string value `"{\"a\":2,\"b\":1}"` is evaluated against object property `{"b": 1, "a": 2}`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with nested-array value `[[1,2]]` is evaluated against array property `[1,2]`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with object value `{"a":2,"b":1}` is evaluated against object property `{"b":1,"a":2}`
- **THEN** the local evaluation result should be true

#### Scenario Outline: Numbers use serde_json canonical spellings

- **WHEN** an `exact` filter with string value <string-value> is evaluated against numeric property <property>
- **THEN** the local evaluation result should be true

  | string-value | property |
  | `"-0.0"` | `-0.0` |
  | `"1e-7"` | `0.0000001` |
  | `"1e+16"` | `10000000000000000.0` |
  | `"0.00001"` | `0.00001` |
  | `"0.000099"` | `0.000099` |

#### Scenario: A collapsed host number is not reconstructed

- **GIVEN** the SDK runtime represents source JSON values `323` and `323.0` as the same host value
- **WHEN** that host value reaches local property matching
- **THEN** the evaluator should not guess whether the source value was an integer or floating-point number
- **AND** it should return inconclusive when its result model supports safe remote fallback
- **OR** it should use one documented deterministic representation when no inconclusive result exists
### Requirement: Backend boolean gate and Unicode-lowercase exact property filters

The local evaluator SHALL implement `exact` and `is_not` with the flags service's ordered algorithm. It SHALL first classify the complete filter value as boolean-like. JSON booleans and case-insensitive strings `"true"` and `"false"` are boolean-like. A JSON array is boolean-like when every element is recursively boolean-like. An empty array is therefore boolean-like because every element of an empty iterator satisfies the predicate.

When the filter is boolean-like, the evaluator SHALL compare its aggregate truthiness with the property's aggregate truthiness before applying ordinary filter-array membership or stringification. A boolean is truthy according to its value. A string is truthy only when it case-insensitively equals `"true"`. An array is truthy when every element is recursively truthy, including an empty array. Every other JSON value is falsey. The property need not itself be boolean-like, so a false-like filter currently matches arbitrary falsey values such as `"banana"`, `0`, null, `{}`, and `""`.

When the filter is not boolean-like and is an array, the evaluator SHALL independently stringify and full-Unicode-lowercase each array element. `exact` SHALL match when ANY element equals the stringified, full-Unicode-lowercased property value. When the filter is neither boolean-like nor an array, the evaluator SHALL stringify and full-Unicode-lowercase the filter and property before comparing them. `is_not` SHALL be the logical negation of the complete exact result.

Full Unicode lowercase SHALL reproduce Rust `str::to_lowercase`, including context-sensitive and multi-code-point mappings. Implementations MUST NOT substitute ASCII-only lowercase, Unicode casefold/equivalence, accent removal, locale-sensitive comparison, simple Unicode lowercase, or a generic case-insensitive collation whose results differ from Rust lowercase-then-compare.

When the required property key is absent from caller-supplied local evaluation context, both operators SHALL remain inconclusive and eligible for remote fallback.

#### Scenario: A false-like filter uses aggregate truthiness

- **WHEN** an `exact` filter with value `false`, `"false"`, or `["false"]` is evaluated against property `"banana"`, `0`, null, `{}`, or `""`
- **THEN** the local evaluation result should be true
- **AND** the corresponding `is_not` filter should return false

#### Scenario: A boolean-like array takes precedence over ANY membership

- **WHEN** an `exact` filter with value `["true", "false"]` is evaluated against property `"true"`
- **THEN** the local evaluation result should be false
- **WHEN** the same filter is evaluated against property `"pro"`
- **THEN** the local evaluation result should be true

#### Scenario: An empty filter array is vacuously truthy

- **WHEN** an `exact` filter with value `[]` is evaluated against property `true`, `"true"`, `[]`, or `[true]`
- **THEN** the local evaluation result should be true
- **WHEN** the same filter is evaluated against property `"us"`, null, false, or `1`
- **THEN** the local evaluation result should be false
- **AND** `is_not` should return the logical inverse in every case

#### Scenario: A non-boolean-like array uses case-insensitive ANY membership

- **WHEN** an `exact` filter with value `["FREE", "PRO"]` is evaluated against property `"pro"`
- **THEN** the local evaluation result should be true
- **AND** the corresponding `is_not` filter should return false

#### Scenario: Unicode lowercase matches non-ASCII case variants

- **WHEN** an `exact` filter with value `"ä"` is evaluated against property `"Ä"`
- **THEN** the local evaluation result should be true

#### Scenario: Unicode casefold expansion is not exact lowercase equality

- **WHEN** an `exact` filter with value `"ss"` is evaluated against property `"ß"`
- **THEN** the local evaluation result should be false

#### Scenario: A single sigma does not equal final sigma

- **WHEN** an `exact` filter with value `"ς"` is evaluated against property `"Σ"`
- **THEN** the local evaluation result should be false

#### Scenario: Full lowercase applies contextual final sigma

- **WHEN** an `exact` filter with value `"οδος"` is evaluated against property `"ΟΔΟΣ"`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with value `"οδοσ"` is evaluated against property `"ΟΔΟΣ"`
- **THEN** the local evaluation result should be false

#### Scenario: Full lowercase expands dotted capital I

- **WHEN** an `exact` filter with value `"i̇"` is evaluated against property `"İ"`
- **THEN** the local evaluation result should be true
- **WHEN** an `exact` filter with value `"i"` is evaluated against property `"İ"`
- **THEN** the local evaluation result should be false

#### Scenario: Unicode normalization is not applied

- **WHEN** an `exact` filter with composed value `"é"` is evaluated against decomposed property `"É"`
- **THEN** the local evaluation result should be false

#### Scenario: Missing equality property is inconclusive

- **WHEN** an `exact` or `is_not` filter is evaluated without its required property in the supplied context
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled
### Requirement: ASCII-lowercase string search property filters

The local evaluator SHALL implement `icontains`, `not_icontains`, `icontains_multi`, `not_icontains_multi`, `starts_with`, `not_starts_with`, `ends_with`, and `not_ends_with` by stringifying operands with the backend-compatible representation above and lowercasing only ASCII characters `A` through `Z`. It SHALL then apply the corresponding substring, prefix, or suffix check. Each `not_*` operator SHALL be the logical negation of its positive operator for a present, supported property value. These operators MUST NOT use Unicode lowercase, Unicode casefold/equivalence, locale-sensitive comparison, normalization, or accent removal.

For `icontains_multi` and `not_icontains_multi`, an array condition SHALL be evaluated as an ANY list after independently stringifying and ASCII-lowercasing every member. The direct authoring API requires this array shape but does not require every member to be a string. For runtime compatibility, a scalar condition SHALL be treated as one search value. Array/object properties and scalar or composite condition members participate through backend-compatible stringification.

An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. When the required property key is absent from caller-supplied local evaluation context, every operator in this family SHALL remain inconclusive and eligible for remote fallback.

#### Scenario: ASCII case variants match all positive search operators

- **WHEN** filters use ASCII case variants between their values and the supplied property
- **THEN** `icontains`, `icontains_multi`, `starts_with`, and `ends_with` should perform case-insensitive matches
- **AND** their corresponding `not_*` operators should return the logical inverse

#### Scenario Outline: Multi-contains supports authorable lists and runtime-compatible scalars

- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | true |
  | `not_icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | false |
  | `icontains_multi` | `[]` | `"pro account"` | false |
  | `not_icontains_multi` | `[]` | `"pro account"` | true |
  | `icontains_multi` | `"PRO"` | `"pro account"` | true |
  | `icontains_multi` | `[2, {"a":1}]` | `"item 2"` | true |
  | `icontains` | `"[1,2]"` | `[1,2]` | true |

#### Scenario: Non-ASCII case variants do not match the ASCII family

- **WHEN** an `icontains`, `icontains_multi`, or `starts_with` filter with value `"ä"` is evaluated against property `"Äbc"`
- **THEN** the local evaluation result should be false
- **WHEN** an `ends_with` filter with value `"ä"` is evaluated against property `"bcÄ"`
- **THEN** the local evaluation result should be false
- **AND** the corresponding `not_*` operators should return true

#### Scenario: Missing string-search property is inconclusive

- **WHEN** any string-search operator is evaluated without its required property in the supplied context
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled
### Requirement: Unrecognized property-filter operators degrade to inconclusive

The local evaluator SHALL treat any property-filter operator string it does not recognize as
inconclusive for that flag — deferring to remote evaluation for that flag only — rather than
raising an unhandled error. This includes, for example, a new server-side operator not yet
supported by that SDK's evaluator. This inconclusive signal SHALL NOT disable or interrupt local
evaluation of other flags in the same evaluation pass; only the flag using the unrecognized
operator falls back to remote evaluation.

This isolation SHALL apply at the raw local-definition decoding boundary, not only after an in-memory typed property object has been constructed. An implementation that represents operators as a closed enum SHALL catch an unknown operator while decoding the individual flag and preserve the rest of the payload. It MUST NOT reject the complete polled-definition bundle because one flag contains a future operator. This flag-local policy is intentionally stronger than the released flags service's typed hypercache bundle decoding, where one unknown enum value can reject the team payload.

This mirrors how other inconclusive conditions in this evaluator are scoped (for example a
missing required property), so that one flag definition using an operator ahead of a given
SDK's support does not take down local evaluation project-wide.

#### Scenario: An unrecognized operator defers only that flag to remote evaluation
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "future-op-flag" matching person
  property "plan" with an operator this SDK version does not recognize
- **WHEN** local feature flag "future-op-flag" is evaluated for a person with property "plan"
  equal to "enterprise"
- **THEN** local evaluation should be inconclusive for "future-op-flag"

#### Scenario: Other flags keep evaluating locally despite one unrecognized operator
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "future-op-flag" matching person
  property "plan" with an operator this SDK version does not recognize
- **AND** local feature flag definitions include a flag "beta-ui" rolled out to distinct id
  "user-123"
- **WHEN** local feature flag "future-op-flag" is evaluated for distinct id "user-123"
- **AND** local feature flag "beta-ui" is evaluated for distinct id "user-123"
- **THEN** local evaluation should be inconclusive for "future-op-flag"
- **AND** the local evaluation result for "beta-ui" should be true

#### Scenario: An unknown operator is isolated while decoding a definition bundle (@server)
- **GIVEN** one raw polled-definition payload contains a flag with operator `future_operator`
- **AND** the same payload contains an independent rollout-only flag
- **WHEN** the SDK decodes and installs the payload
- **THEN** only the flag with `future_operator` should require remote fallback
- **AND** the independent flag should remain available for local evaluation

#### Scenario: An evaluator error is isolated to one bulk result (@server)
- **GIVEN** one flag produces a matcher or evaluator error during bulk local evaluation
- **AND** an independent rollout-only flag can be evaluated locally
- **WHEN** both flags are evaluated in one pass
- **THEN** the failing flag should be inconclusive
- **AND** the independent flag should still return its local result
### Requirement: Flag dependency filters compare evaluated flag values

A condition filter with property type `flag` SHALL use the `flag_evaluates_to` operator and compare its expected value with the referenced flag's evaluated value. Expected boolean `true` SHALL match boolean `true` and any multivariate variant string, but SHALL NOT match boolean `false`. Expected boolean `false` SHALL match only boolean `false`. An expected string SHALL match only the identical multivariate variant string, using a case-sensitive comparison.

Dependency filters SHALL be ANDed with every other filter in their condition. The evaluator SHALL resolve dependencies before selecting the dependent condition and MAY cache each dependency result for the current evaluation pass.

In SDK local-definition payloads, a dependency filter's `key` SHALL identify the referenced feature-flag key, not its database ID. A flag's `dependency_chain` SHALL list every transitively required definition in topological evaluation order, including the immediate dependency and excluding the owning flag. For `A`, `B → A`, and `C → B → A`, the chains are respectively empty, `[A]`, and `[A, B]`. An empty chain caused by a missing definition or cycle MUST NOT be interpreted as proof that the flag has no dependencies.

A missing definition, unresolved dependency, or cycle SHALL make the dependent flag locally inconclusive and eligible for remote fallback; it SHALL NOT prevent independent flags in the same evaluation pass from being evaluated locally. An inactive or filtered referenced definition remains resolvable as boolean `false`: a dependency expecting `false` matches definitively, while one expecting `true` definitively does not match.

#### Scenario: Flag dependency filters compare evaluated values (@server)
- **GIVEN** flag "banner" has a `flag_evaluates_to` condition referencing flag "checkout"
- **WHEN** "checkout" is evaluated and compared with the dependency's expected value
- **THEN** the dependency filter should produce these results:

  | evaluated value | expected value | matches |
  | --- | --- | --- |
  | `true` | `true` | true |
  | `"test"` | `true` | true |
  | `false` | `false` | true |
  | `true` | `false` | false |
  | `"test"` | `"test"` | true |
  | `"test"` | `"Test"` | false |
  | `"control"` | `"test"` | false |

#### Scenario: An unresolved dependency affects only the dependent flag (@server)
- **GIVEN** flag "banner" depends on a flag definition that is missing or cannot be resolved locally
- **AND** independent flag "beta-ui" can be evaluated from local definitions and context
- **WHEN** both flags are evaluated locally
- **THEN** local evaluation should be inconclusive for "banner"
- **AND** "beta-ui" should still be evaluated locally

#### Scenario: Dependency chains use flag keys in topological order (@server)
- **GIVEN** local definitions contain `A`, `B → A`, and `C → B → A`
- **WHEN** the SDK resolves the dependency filters and chains
- **THEN** `B` should reference key `A` and have chain `[A]`
- **AND** `C` should reference key `B` and have chain `[A, B]`

#### Scenario: An inactive dependency resolves as false (@server)
- **GIVEN** inactive flag `A` is retained as a dependency of active flags `B` and `C`
- **AND** `B` expects `A` to evaluate to false
- **AND** `C` expects `A` to evaluate to true
- **WHEN** `B` and `C` are evaluated locally
- **THEN** the dependency criterion for `B` should match
- **AND** the dependency criterion for `C` should not match
