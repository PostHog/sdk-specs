## ADDED Requirements

### Requirement: Backend-compatible property-filter stringification

The local evaluator SHALL stringify operands before applying the `exact`, `is_not`, `icontains`, `not_icontains`, `starts_with`,
`not_starts_with`, `ends_with`, or `not_ends_with` operator, converting
both operands to the same string representation used by the flags service. A JSON string SHALL
contribute its unquoted contents. A non-string JSON value SHALL use its JSON lexical
representation, including lowercase JSON booleans and null and JSON syntax for arrays and
objects. The `exact`/`is_not` filter-array behavior specified separately below takes precedence
over stringifying the filter array as one value.

When the input representation preserves numeric kind and spelling, integer `323` SHALL stringify
as `"323"` and floating-point `323.0` SHALL stringify as `"323.0"`. If a host runtime has already
collapsed those JSON tokens into one indistinguishable host value before the evaluator receives
it, the SDK SHALL stringify the received value deterministically and MUST NOT infer or invent the
discarded lexical form. This representational limitation does not permit locale-dependent numeric
formatting.

#### Scenario: Integer property matches its string representation

- **WHEN** an `exact` filter with string value `"323"` is evaluated against JSON integer property `323`
- **THEN** the local evaluation result should be true

#### Scenario: Preserved floating-point spelling remains distinct

- **GIVEN** the SDK runtime preserves JSON floating-point value `323.0` distinctly from JSON integer `323`
- **WHEN** an `exact` filter with string value `"323.0"` is evaluated against property `323.0`
- **THEN** the local evaluation result should be true
- **AND** an `ends_with` filter with string value `"3"` should not match that property

#### Scenario: A collapsed host number is not reconstructed

- **GIVEN** the SDK runtime represents source JSON values `323` and `323.0` as the same host value
- **WHEN** that host value reaches local property matching
- **THEN** the evaluator should use one deterministic, locale-independent string representation
- **AND** the evaluator should not guess whether the source token contained a decimal suffix

### Requirement: Unicode-lowercase exact property filters

The local evaluator SHALL implement `exact` and `is_not` by stringifying the property value and filter candidate,
lowercasing both strings with the runtime's locale-independent Unicode lowercase
transformation, and comparing the resulting strings for equality. It MUST NOT substitute ASCII-only
lowercase, Unicode casefold/equivalence, accent removal, locale-sensitive comparison, or a generic
case-insensitive collation whose results differ from lowercase-then-compare. `is_not` SHALL be the
logical negation of the complete exact match.

When an `exact` or `is_not` filter value is an array, the evaluator SHALL independently stringify
and Unicode-lowercase each array element. `exact` SHALL match when ANY element equals the
stringified, Unicode-lowercased property value. `is_not` SHALL match when NONE of the elements
equals it. An empty array therefore SHALL NOT match `exact` and SHALL match `is_not`.

When the required property key is absent from caller-supplied local evaluation context, both
operators SHALL remain inconclusive and eligible for remote fallback.

#### Scenario: Unicode lowercase matches non-ASCII case variants

- **WHEN** an `exact` filter with value `"ä"` is evaluated against property `"Ä"`
- **THEN** the local evaluation result should be true

#### Scenario: Unicode casefold expansion is not exact lowercase equality

- **WHEN** an `exact` filter with value `"ss"` is evaluated against property `"ß"`
- **THEN** the local evaluation result should be false

#### Scenario: Final sigma is not equivalent under lowercase comparison

- **WHEN** an `exact` filter with value `"ς"` is evaluated against property `"Σ"`
- **THEN** the local evaluation result should be false

#### Scenario: Exact array matching uses case-insensitive ANY membership

- **WHEN** an `exact` filter with value `["FREE", "PRO"]` is evaluated against property `"pro"`
- **THEN** the local evaluation result should be true
- **AND** the corresponding `is_not` filter should return false

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
