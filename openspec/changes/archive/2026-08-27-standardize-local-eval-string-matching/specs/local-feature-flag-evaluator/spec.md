## ADDED Requirements

### Requirement: Backend-compatible property-filter stringification

The local evaluator SHALL stringify operands before applying the `exact`, `is_not`, `icontains`, `not_icontains`, `starts_with`,
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

#### Scenario: Missing equality property is inconclusive

- **WHEN** an `exact` or `is_not` filter is evaluated without its required property in the supplied context
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

### Requirement: ASCII-lowercase string search property filters

The local evaluator SHALL implement `icontains`, `not_icontains`, `starts_with`, `not_starts_with`,
`ends_with`, and `not_ends_with` by stringifying both operands and lowercasing
only ASCII characters `A` through `Z`. It SHALL then apply the corresponding substring, prefix, or
suffix check. Each `not_*` operator SHALL be the logical negation of its positive operator for a
present, supported property value. These operators MUST NOT use Unicode lowercase, Unicode
casefold/equivalence, locale-sensitive comparison, or accent removal.

When the required property key is absent from caller-supplied local evaluation context, these
operators SHALL remain inconclusive and eligible for remote fallback.

#### Scenario: ASCII case variants match all positive search operators

- **WHEN** filters use ASCII case variants between their values and the supplied property
- **THEN** `icontains`, `starts_with`, and `ends_with` should perform case-insensitive matches
- **AND** their corresponding `not_*` operators should return the logical inverse

#### Scenario: Non-ASCII case variants do not match the ASCII family

- **WHEN** an `icontains` or `starts_with` filter with value `"ä"` is evaluated against property `"Äbc"`
- **THEN** the local evaluation result should be false
- **WHEN** an `ends_with` filter with value `"ä"` is evaluated against property `"bcÄ"`
- **THEN** the local evaluation result should be false
- **AND** the corresponding `not_*` operators should return true

#### Scenario: Missing string-search property is inconclusive

- **WHEN** any string-search operator is evaluated without its required property in the supplied context
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

## REMOVED Requirements

### Requirement: String prefix/suffix property filter operators

**Reason**: The narrower requirement is superseded by the complete backend-compatible stringification, equality, and ASCII string-search requirements above.

**Migration**: Implementations that already satisfy prefix/suffix behavior retain it under `ASCII-lowercase string search property filters` and add the specified `icontains`, equality, and stringification semantics.
