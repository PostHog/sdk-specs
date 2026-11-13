## MODIFIED Requirements

### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition SHALL be a string pattern. The evaluator SHALL stringify the supplied property using the compact JSON rules defined for equality. Matching SHALL be case-sensitive unless the pattern enables case-insensitive behavior, and SHALL search the input without adding implicit anchors. An empty pattern therefore matches every present property value. `not_regex` SHALL negate only a successfully compiled and executed search result.

An unescaped `^` SHALL anchor at the start of the whole input and an unescaped `$` SHALL anchor at its end, unless the pattern itself enables multiline behavior. A trailing line feed SHALL NOT be exempt from the end anchor: `^foo$` SHALL NOT match `"foo\n"`. An SDK whose regex engine applies a different default SHALL translate the anchor or defer the criterion rather than return the engine's divergent result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. Syntax unsupported by an SDK's regex engine, or a regex execution failure, SHALL be inconclusive for that flag and MUST NOT become a match through `not_regex` or cohort negation. Regex matching MUST NOT throw into application code. Where an SDK's engine classifies a construct as valid that the flags service rejects, or the reverse, the SDK SHALL defer the criterion instead of returning the definitive no-match.

Local regex matching SHALL be limited to a portable subset on which the SDK's regex engine agrees with the flags service. When the pattern or the stringified input falls outside that subset, the criterion SHALL be inconclusive **even when the local engine would return a definitive result**, and the SDK SHALL use remote evaluation where remote fallback is permitted. Divergence classes that SHALL fall outside the subset include:

- non-ASCII patterns, or non-ASCII inputs matched by shorthand classes such as `\d`, `\w`, and `\s` or by Unicode property escapes such as `\p{L}`, whose membership differs between engines;
- word boundaries `\b` and `\B` outside a character class, which can exhaust the service's bounded backtracking budget on short inputs — `[\b]` as a backspace literal stays in the subset;
- quantified assertions, nested or orphan-group quantification, and oversized repeat counts, whose evaluation can exceed the service's step budget or the SDK's own resource limits;
- constructs only one engine compiles, such as lookarounds, backreferences, class set operations, and engine-specific boundary escapes.

A deferral under this requirement carries the same guarantees as an unsupported-syntax deferral: it MUST NOT become a match through `not_regex` or cohort negation, and local-only evaluation SHALL remain unresolved rather than substituting a guessed boolean. The subset is deliberately conservative — patterns and inputs that would in fact have agreed MAY still defer, at the cost of more remote flag requests and more unresolved local-only results. SDKs SHALL NOT trade that cost for a locally computed boolean that the service would contradict. These rules are a portability contract, not a claim of complete equivalence across every Unicode version, compiler limit, or resource budget.

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
  | `regex` | `"^foo$"` | `"foo\n"` | false |
  | `not_regex` | `"^foo$"` | `"foo\n"` | true |

#### Scenario: Unsupported regex execution is inconclusive (@server)
- **GIVEN** a pattern uses syntax unsupported by the SDK regex engine
- **WHEN** the pattern is evaluated with `regex` or `not_regex`
- **THEN** local evaluation should be inconclusive for that flag
- **AND** neither a negative operator nor cohort negation should turn the failure into a match

#### Scenario Outline: Engine-divergent regex evaluation defers to the service (@server)
- **GIVEN** a local property condition with operator <operator> and pattern <pattern>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** local evaluation should be inconclusive for that flag
- **AND** the SDK should request remote evaluation when remote fallback is permitted
- **AND** local-only evaluation should remain unresolved rather than returning a definitive result
- **AND** neither a negative operator nor cohort negation should turn the deferral into a match

  | operator | pattern | property |
  | `regex` | `"^\\d+$"` | `"١٢٣"` |
  | `not_regex` | `"^\\d+$"` | `"١٢٣"` |
  | `regex` | `"^\\p{L}+$"` | `"café"` |
  | `regex` | `"^a\\b$"` | `"a"` |
  | `regex` | `"^(a+)+$"` | `"aaaaaaaaaaaaaaaaaaaaaaaaaaa\n"` |

#### Scenario: Portable ASCII regex criteria stay local (@server)
- **GIVEN** a local property condition with operator `regex` and pattern `"example\\.com"`
- **WHEN** it is evaluated against supplied property value `"admin@example.com"`
- **THEN** the criterion match result should be true
- **AND** no remote flag evaluation request should be sent
