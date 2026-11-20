## MODIFIED Requirements

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

Because caller-supplied local property maps are partial context, an absent required property key that is not listed as known absent SHALL make that criterion inconclusive for every ordinary property operator, including named negative operators. A value-requiring operator whose condition value is omitted SHALL be inconclusive. An operator that is unknown or invalid for the criterion type SHALL be inconclusive for only the affected flag.

A required property key listed as known absent is not missing context. The criterion SHALL be definitive, without remote fallback, and SHALL use these results regardless of the condition value. The evaluator SHALL NOT parse, compile, or validate a present condition value for a known-absent key, so an invalid pattern or a malformed numeric, date, or version operand does not change the result. This matches the flags service, which removes a listed key before matching and decides each operator from its missing-value branch before it reads the condition value:

| Operator | Result for a known-absent key |
| --- | --- |
| `is_not_set` | match |
| `is_not`, `not_icontains`, `not_starts_with`, `not_ends_with`, `not_icontains_multi`, `not_regex`, `not_between` | match |
| `is_set` | no match |
| every other operator, including `exact`, `icontains`, `icontains_multi`, `starts_with`, `ends_with`, `regex`, `gt`, `gte`, `lt`, `lte`, `between`, all `semver_*` operators including `semver_neq`, and the `is_date_*` operators | no match |

Known absence SHALL NOT change cohort membership read from stored static or realtime cohorts, SHALL NOT affect holdouts, which read no properties, and SHALL apply to a flag dependency because the dependency evaluates with the same listing. A dynamic-cohort property leaf SHALL use the table above before applying its `negation`.

When the condition value is omitted, a value-requiring operator SHALL remain inconclusive even for a known-absent key, as for any criterion with an omitted condition value.

The known-absent table SHALL apply only to an operator the SDK implements locally. An inventory operator that the SDK does not implement locally SHALL make the flag inconclusive with the `unsupported_definition` cause, even when the key is listed as known absent. The SDK SHALL check operator support before it applies the table, so the flag falls back to remote evaluation and the flags service decides the result.

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. The one exception is `not_between`, which matches a property value that does not convert to a number, as the numeric criteria requirement defines. A malformed condition value SHALL be inconclusive unless an operator-family requirement explicitly defines a safe result. Apart from that `not_between` exception and the known-absent table above, a named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

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
  | `exact` | `"pro"` | the required key listed as known absent | false |
  | `is_not` | `"pro"` | the required key listed as known absent | true |
  | `not_icontains` | `"pro"` | the required key listed as known absent | true |
  | `icontains` | `"pro"` | the required key listed as known absent | false |
  | `gt` | `"10"` | the required key listed as known absent | false |
  | `semver_neq` | `"1.2.3"` | the required key listed as known absent | false |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | the required key listed as known absent | false |
  | `not_regex` | `"["` | the required key listed as known absent | true |
  | `regex` | `"["` | the required key listed as known absent | false |
  | `gt` | `"not-a-number"` | the required key listed as known absent | false |
  | `semver_gt` | `"not-a-version"` | the required key listed as known absent | false |
  | `is_date_after` | `"not-a-date"` | the required key listed as known absent | false |
  | `is_not` | omitted | the required key listed as known absent | inconclusive |
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `"10"` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |

#### Scenario: An operator the SDK does not implement falls back before known absence (@server)
- **GIVEN** a local condition has operator `not_between` and condition value `[1, 2]`
- **AND** the SDK does not implement `not_between` locally
- **WHEN** it is evaluated with the required key listed as known absent
- **THEN** the flag should remain unresolved with reason `unsupported_definition`
- **AND** the criterion should not resolve from the known-absent table

### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition SHALL be a string pattern. The evaluator SHALL stringify the supplied property using the compact JSON rules defined for equality. Matching SHALL be case-sensitive unless the pattern enables case-insensitive behavior, and SHALL search the input without adding implicit anchors. An empty pattern therefore matches every present property value. `not_regex` SHALL negate only a successfully compiled and executed search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. Syntax unsupported by an SDK's regex engine, or a regex execution failure, SHALL be inconclusive for that flag and MUST NOT become a match through `not_regex` or cohort negation. Regex matching MUST NOT throw into application code.

Portable acceptance vectors SHALL use syntax shared by the target SDK engines. Engine-specific constructs require remote fallback when the SDK cannot evaluate them.

These pattern rules apply only when the property key is present. For a key listed as known absent, `regex` SHALL NOT match and `not_regex` SHALL match without compiling the pattern, so an invalid, unsupported, or engine-specific pattern does not change the result, as the canonical operator inventory requirement defines.

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

#### Scenario: A known-absent key resolves regex criteria without compiling the pattern (@server)
- **GIVEN** a local condition uses pattern syntax unsupported by the SDK regex engine
- **WHEN** it is evaluated with the required key listed as known absent
- **THEN** `regex` should not match and `not_regex` should match
- **AND** the SDK should not require remote fallback
