## MODIFIED Requirements

### Requirement: Backend boolean gate and Unicode-lowercase exact property filters

The local evaluator SHALL select `exact` and `is_not` semantics from the definition snapshot's top-level `property_matching_version`. Exactly the numeric version `2` SHALL select explicit matching. Missing version or `1` SHALL select the released flags service's legacy matching, not an SDK-specific historical algorithm. Other versions SHALL NOT activate v2; they SHALL use legacy matching unless the SDK already has a safe-inconclusive policy for unsupported versions. An ordinary older definition document SHALL NOT cause an exception. Individual flag `version`, the `/flags?v=2` response protocol, and `flag_evaluates_to` SHALL NOT select property matching semantics. Backward-compatible property-matching helpers called without a version SHALL default to legacy.

**Legacy (missing/1):** The evaluator SHALL first classify the complete filter value as boolean-like. JSON booleans and case-insensitive strings `"true"` and `"false"` are boolean-like. A JSON array is boolean-like when every element is recursively boolean-like. An empty array is therefore boolean-like because every element of an empty iterator satisfies the predicate.

In legacy mode, when the filter is boolean-like, the evaluator SHALL compare its aggregate truthiness with the property's aggregate truthiness before applying ordinary filter-array membership or stringification. A boolean is truthy according to its value. A string is truthy only when it case-insensitively equals `"true"`. An array is truthy when every element is recursively truthy, including an empty array. Every other JSON value is falsey. The property need not itself be boolean-like, so a false-like filter matches arbitrary falsey values such as `"banana"`, `0`, null, `{}`, and `""`.

In legacy mode, when the filter is not boolean-like and is an array, the evaluator SHALL independently stringify and full-Unicode-lowercase each array element. `exact` SHALL match when ANY element equals the stringified, full-Unicode-lowercased property value. In legacy mode, when the filter is neither boolean-like nor an array, the evaluator SHALL stringify and full-Unicode-lowercase the filter and property before comparing them. `is_not` SHALL be the logical negation of the complete exact result.

**Explicit (2):** A non-array filter SHALL be compared to the whole property using the canonical string representation and full Unicode lowercase. A nonempty filter array SHALL match when ANY independently stringified and full-Unicode-lowercased member equals the stringified and full-Unicode-lowercased whole property. The evaluator SHALL NOT apply aggregate boolean coercion, flatten a property array, or stringify the complete nonempty filter array as a single alternative. An empty filter array `[]` SHALL instead return the legacy recursive truthiness of the property in both modes. `is_not` SHALL negate the complete, conclusive `exact` result in both modes.

The existing canonical stringification and safe numeric-ambiguity fallback rules SHALL continue to apply; selecting v2 SHALL NOT discard a safe inconclusive result. Present JSON null SHALL NOT be treated as a missing property. This requirement does not expand SDK support for malformed or unsupported null filter values.

Full Unicode lowercase SHALL reproduce Rust `str::to_lowercase`, including context-sensitive and multi-code-point mappings. Implementations MUST NOT substitute ASCII-only lowercase, Unicode casefold/equivalence, accent removal, locale-sensitive comparison, simple Unicode lowercase, or a generic case-insensitive collation whose results differ from Rust lowercase-then-compare.

When the required property key is absent from caller-supplied local evaluation context, both operators SHALL remain inconclusive and eligible for remote fallback.

#### Scenario: A false-like filter uses aggregate truthiness

- **GIVEN** the definition snapshot omits `property_matching_version` or sets it to `1`
- **WHEN** an `exact` filter with value `false`, `"false"`, or `["false"]` is evaluated against property `"banana"`, `0`, null, `{}`, or `""`
- **THEN** the local evaluation result should be true
- **AND** the corresponding `is_not` filter should return false

#### Scenario: A boolean-like array takes precedence over ANY membership

- **GIVEN** the definition snapshot omits `property_matching_version` or sets it to `1`
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

#### Scenario: Missing equality property is inconclusive

- **WHEN** an `exact` or `is_not` filter is evaluated without its required property in the supplied context
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

#### Scenario: Six exact comparisons distinguish the selected matching mode

- **GIVEN** all property keys are present and operands retain their JSON kinds
- **WHEN** each comparison is evaluated with a missing version, version `1`, and version `2`
- **THEN** `exact` should return the following results
- **AND** `is_not` should return the logical complement of each result without remote fallback

  | filter | property | missing/1 | 2 |
  | --- | --- | --- | --- |
  | `false` | `"banana"` | true | false |
  | `false` | `0` | true | false |
  | `["true","false"]` | `"true"` | false | true |
  | `["true","false"]` | `"pro"` | true | false |
  | `[]` | `true` | true | true |
  | `[]` | `[]` | true | true |

#### Scenario: Explicit equality distinguishes falsey values and whole property arrays

- **WHEN** `exact` compares `false` with `"FALSE"`
- **THEN** it should match in both modes
- **WHEN** `exact` compares `false` with present null or `""`, or compares `true` with `[true]`
- **THEN** it should match in legacy mode and not match in v2
- **AND** `is_not` should return the complement in each case

#### Scenario: Empty filter truthiness is recursive in both modes

- **WHEN** `exact` compares `[]` with `[true,["TRUE",[]]]`
- **THEN** it should match in both modes
- **WHEN** the property is `[true,[false]]`, false, null, `0`, `1`, or `"banana"`
- **THEN** it should not match in either mode
- **AND** `is_not` should return the complement in each case

#### Scenario: Explicit array members normalize independently

- **GIVEN** the definition snapshot sets `property_matching_version` to `2`
- **WHEN** `exact` compares `["TrUe","FALSE"]` with either boolean, `[false,"PRO"]` with `"pro"`, or `[[true],"PRO"]` with `[true]`
- **THEN** it should match using independently normalized members
- **AND** `is_not` should not match

#### Scenario: Only exactly version 2 enables explicit matching

- **GIVEN** the definition snapshot sets `property_matching_version` to `0` or `3`
- **WHEN** `exact` compares `false` with `"banana"`
- **THEN** it should match using legacy semantics, or remain safely inconclusive under an existing unsupported-version policy
- **AND** it should not return the v2 no-match result or throw an exception

## ADDED Requirements

### Requirement: A stable definition snapshot selects matching throughout local evaluation

The local evaluator SHALL capture the definitions and their matching version as one stable snapshot for an evaluation pass. The same version SHALL govern person conditions, group conditions, property leaves at every recursive dynamic-cohort level, and property comparisons while evaluating flag dependencies. Simple and full-result APIs, single and bulk evaluation, and supported asynchronous or blocking wrappers SHALL use the same snapshot semantics. A concurrently replaced snapshot SHALL NOT change the matching algorithm halfway through one pass. Cached local evaluation results, including dependency results, SHALL NOT survive a version-only change unless they are isolated by snapshot/version.

The separate `flag_evaluates_to` comparison of evaluated boolean/variant values SHALL remain unchanged. Property matching version changes the evaluation of a referenced flag's property rules, not the meaning of the dependency operator.

These requirements apply to SDKs that actually evaluate local rule definitions (or delegate to such an evaluator). Reading previously evaluated remote flag values, including mobile/browser value caches and wrapper getters, SHALL NOT itself count as local-rule evaluation or demonstrate conformance.

#### Scenario: Person group and recursive cohort properties share the version

- **GIVEN** a snapshot contains a person condition, a company group condition with group mapping `0` to `company`, and a dynamic cohort with an AND group referencing another cohort whose OR group contains a person-property leaf
- **AND** each property leaf compares its present property with filter `false` using `exact`
- **WHEN** all relevant properties are `"banana"` and group key `acme` is supplied
- **THEN** all three flags should evaluate to true for missing/1 and false for 2 without remote fallback
- **AND** replacing all three equality operators with `is_not` should complement every result

#### Scenario: Dependency evaluation inherits matching but not boolean comparison coercion

- **GIVEN** flag `source` has a person property `exact false` condition and flag `dependent` requires `source` to evaluate to boolean true
- **WHEN** the property is `"banana"`
- **THEN** both flags should be true for missing/1 and false for 2
- **AND** a dependency expecting boolean true should still match a referenced multivariate variant string in either mode

#### Scenario: A concurrent reload does not mix matching versions

- **GIVEN** a bulk evaluation has captured a version-1 definition snapshot
- **WHEN** a version-2 snapshot replaces it before a recursive cohort or dependency is evaluated
- **THEN** every comparison in the in-flight pass should still use version 1
- **AND** the next evaluation pass should use version 2, without reusing version-1 cached results
