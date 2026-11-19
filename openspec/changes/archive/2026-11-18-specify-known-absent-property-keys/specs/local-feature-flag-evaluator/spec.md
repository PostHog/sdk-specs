## MODIFIED Requirements

### Requirement: is_set and is_not_set distinguish property presence from unavailable context

The local evaluator SHALL match an `is_set` property filter whenever the required evaluation property key is present. A property explicitly supplied with the platform's JSON null equivalent SHALL match `is_set`, because the key is present.

Boolean false, numeric zero, an empty string, and empty collections SHALL also count as set. Implementations SHALL test property membership and SHALL NOT use generic language truthiness or a non-null check to decide whether a property is set.

When the required property key is absent from caller-supplied local evaluation context, `is_set` SHALL remain inconclusive and defer to remote evaluation when remote fallback is enabled. Omission from request-time properties does not prove that the property is absent from PostHog's stored person or group properties.

The local evaluator SHALL definitively not match an `is_not_set` property filter whenever the required evaluation property key is present, including when its value is null or another falsey value. When the key is absent from caller-supplied local evaluation context, `is_not_set` SHALL remain inconclusive and SHALL NOT match solely because the key was omitted.

Caller-supplied property maps represent present values or unavailable context. They do not by themselves represent affirmative knowledge that a property is absent.

An SDK MAY accept a known-absence input: a set of person property keys, and for each group type a set of group property keys, that the caller knows are absent for this evaluation. A listed key is absent, not missing context. The listing SHALL take precedence over any value for the same key in the supplied person or group properties. For a listed key, `is_not_set` SHALL match and `is_set` SHALL NOT match, both without remote fallback. Other operators on a listed key follow the canonical operator inventory requirement.

A key that is omitted from the supplied properties and not listed SHALL remain inconclusive, as described above. Listing a key SHALL NOT affect any other key. Person keys that carry the flags service's person-metadata prefix (`__posthog_person_metadata__`) SHALL be ignored, so known absence never hides a persons-table field such as `created_at`. Group keys are scoped to the named group type, so a key listed for one group type SHALL NOT apply to another.

#### Scenario: Explicit null matches is_set
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally with person property "plan" explicitly set to null
- **THEN** the local evaluation result should be true
- **AND** the SDK should not require remote fallback solely to interpret the explicit null value

#### Scenario: Other falsey present values match is_set
- **GIVEN** local feature flags use `is_set` filters for properties supplied as false, zero, an empty string, an empty list, and an empty object
- **WHEN** those flags are evaluated locally
- **THEN** each `is_set` property comparison should match

#### Scenario: Missing property context leaves is_set inconclusive
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

#### Scenario: Explicit null does not match is_not_set
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with person property "plan" explicitly set to null
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback solely to interpret the explicit null value

#### Scenario: Other falsey present values do not match is_not_set
- **GIVEN** local feature flags use `is_not_set` filters for properties supplied as false, zero, an empty string, an empty list, and an empty object
- **WHEN** those flags are evaluated locally
- **THEN** each `is_not_set` property comparison should not match

#### Scenario: Listed known-absent key matches is_not_set
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with person property key "plan" listed as known absent and no "plan" entry in the supplied person properties
- **THEN** the local evaluation result should be true
- **AND** the SDK should not require remote fallback

#### Scenario: Listed known-absent key does not match is_set
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally with person property key "plan" listed as known absent
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback

#### Scenario: Listed known-absent key overrides a supplied value
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with person property "plan" set to "pro" and person property key "plan" listed as known absent
- **THEN** the local evaluation result should be true

#### Scenario: Group known-absent key applies only to its group type
- **GIVEN** local feature flag "org-incomplete" matches group property "tier" of group type "organization" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with group property key "tier" listed as known absent for group type "project" only
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

#### Scenario: Omitted key that is not listed stays inconclusive
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with person property key "region" listed as known absent and no "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

#### Scenario: Person-metadata key is ignored
- **GIVEN** a local feature flag matches the persons-table `created_at` field through a person-metadata filter
- **WHEN** the flag is evaluated locally with person property key `__posthog_person_metadata__created_at` listed as known absent
- **THEN** the persons-table `created_at` value should still be used for matching

#### Scenario: Missing property context leaves is_not_set inconclusive
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

### Requirement: Backend boolean gate and Unicode-lowercase exact property filters

The local evaluator SHALL select `exact` and `is_not` semantics from the definition snapshot's top-level `property_matching_version`. Exactly the numeric version `2` SHALL select explicit matching. Missing version or `1` SHALL select the released flags service's legacy matching, not an SDK-specific historical algorithm. Other versions SHALL NOT activate v2; they SHALL use legacy matching unless the SDK already has a safe-inconclusive policy for unsupported versions. An ordinary older definition document SHALL NOT cause an exception. Individual flag `version`, the `/flags?v=2` response protocol, and `flag_evaluates_to` SHALL NOT select property matching semantics. Backward-compatible property-matching helpers called without a version SHALL default to legacy.

**Legacy (missing/1):** The evaluator SHALL first classify the complete filter value as boolean-like. JSON booleans and case-insensitive strings `"true"` and `"false"` are boolean-like. A JSON array is boolean-like when every element is recursively boolean-like. An empty array is therefore boolean-like because every element of an empty iterator satisfies the predicate.

In legacy mode, when the filter is boolean-like, the evaluator SHALL compare its aggregate truthiness with the property's aggregate truthiness before applying ordinary filter-array membership or stringification. A boolean is truthy according to its value. A string is truthy only when it case-insensitively equals `"true"`. An array is truthy when every element is recursively truthy, including an empty array. Every other JSON value is falsey. The property need not itself be boolean-like, so a false-like filter matches arbitrary falsey values such as `"banana"`, `0`, null, `{}`, and `""`.

In legacy mode, when the filter is not boolean-like and is an array, the evaluator SHALL independently stringify and full-Unicode-lowercase each array element. `exact` SHALL match when ANY element equals the stringified, full-Unicode-lowercased property value. In legacy mode, when the filter is neither boolean-like nor an array, the evaluator SHALL stringify and full-Unicode-lowercase the filter and property before comparing them. `is_not` SHALL be the logical negation of the complete exact result.

**Explicit (2):** A non-array filter SHALL be compared to the whole property using the canonical string representation and full Unicode lowercase. A nonempty filter array SHALL match when ANY independently stringified and full-Unicode-lowercased member equals the stringified and full-Unicode-lowercased whole property. The evaluator SHALL NOT apply aggregate boolean coercion, flatten a property array, or stringify the complete nonempty filter array as a single alternative. An empty filter array `[]` SHALL instead return the legacy recursive truthiness of the property in both modes. `is_not` SHALL negate the complete, conclusive `exact` result in both modes.

The existing canonical stringification and safe numeric-ambiguity fallback rules SHALL continue to apply; selecting v2 SHALL NOT discard a safe inconclusive result. Present JSON null SHALL NOT be treated as a missing property. This requirement does not expand SDK support for malformed or unsupported null filter values.

Full Unicode lowercase SHALL reproduce Rust `str::to_lowercase`, including context-sensitive and multi-code-point mappings. Implementations MUST NOT substitute ASCII-only lowercase, Unicode casefold/equivalence, accent removal, locale-sensitive comparison, simple Unicode lowercase, or a generic case-insensitive collation whose results differ from Rust lowercase-then-compare.

When the required property key is absent from caller-supplied local evaluation context and is not listed as known absent, both operators SHALL remain inconclusive and eligible for remote fallback. A key listed as known absent is not missing context: `exact` SHALL NOT match and `is_not` SHALL match, as defined by the canonical operator inventory requirement.

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

### Requirement: ASCII-lowercase string search property filters

The local evaluator SHALL implement `icontains`, `not_icontains`, `starts_with`, `not_starts_with`,
`ends_with`, and `not_ends_with` by stringifying both operands and lowercasing
only ASCII characters `A` through `Z`. It SHALL then apply the corresponding substring, prefix, or
suffix check. Each `not_*` operator SHALL be the logical negation of its positive operator for a
present, supported property value. These operators MUST NOT use Unicode lowercase, Unicode
casefold/equivalence, locale-sensitive comparison, or accent removal.

When the required property key is absent from caller-supplied local evaluation context and is not listed as known absent, these
operators SHALL remain inconclusive and eligible for remote fallback. A key listed as known absent is not missing context: the positive operators SHALL NOT match and each `not_*` operator SHALL match, as defined by the canonical operator inventory requirement.

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

### Requirement: Multi-contains string search uses ANY semantics

The local evaluator SHALL implement `icontains_multi` and `not_icontains_multi` with an array condition. It SHALL stringify the supplied property and each condition member with the backend-compatible representation, lowercase only ASCII characters `A` through `Z`, and compare each member as a substring. `icontains_multi` SHALL match when ANY member matches. `not_icontains_multi` SHALL be the logical inverse for a present, supported property value.

An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. When the required property key is absent from caller-supplied local evaluation context and is not listed as known absent, both operators SHALL remain inconclusive and eligible for remote fallback. A key listed as known absent is not missing context: `icontains_multi` SHALL NOT match and `not_icontains_multi` SHALL match, even when the condition array is empty.

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

A required property key listed as known absent is not missing context. The criterion SHALL be definitive, without remote fallback, and SHALL use these results regardless of the condition value:

| Operator | Result for a known-absent key |
| --- | --- |
| `is_not_set` | match |
| `is_not`, `not_icontains`, `not_starts_with`, `not_ends_with`, `not_icontains_multi`, `not_regex`, `not_between` | match |
| `is_set` | no match |
| every other operator, including `exact`, `icontains`, `icontains_multi`, `starts_with`, `ends_with`, `regex`, `gt`, `gte`, `lt`, `lte`, `between`, all `semver_*` operators including `semver_neq`, and the `is_date_*` operators | no match |

Known absence SHALL NOT change cohort membership read from stored static or realtime cohorts, SHALL NOT affect holdouts, which read no properties, and SHALL apply to a flag dependency because the dependency evaluates with the same listing. A dynamic-cohort property leaf SHALL use the table above before applying its `negation`.

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. The one exception is `not_between`, which matches a property value that does not convert to a number, as the numeric criteria requirement defines. A malformed condition value SHALL be inconclusive unless an operator-family requirement explicitly defines a safe result. Apart from that `not_between` exception, a named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

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
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `"10"` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |

### Requirement: Unavailable enrollment context remains inconclusive

For an active flag without experience continuity, when `filters.feature_enrollment` is true and the enrollment property is absent from the caller's local person-property context and is not listed as known absent, the evaluator SHALL report inconclusive rather than treating the person as opted out or continuing through holdouts and release conditions. Omitted caller properties do not establish absence from stored person properties. When the person property key `$feature_enrollment/<flag key>` is listed as known absent, the enrollment property is not missing context. The evaluator SHALL treat the person as not enrolled, SHALL NOT report `missing_context`, and SHALL continue through holdouts and release conditions as for any person without the enrollment property. The listing SHALL take precedence over a supplied value for the same key. Existing remote fallback SHALL remain eligible; local-only evaluation SHALL make no remote request and SHALL preserve the public API's unresolved-result behavior. For a snapshot API exposing unresolved reasons, missing enrollment context SHALL contribute the `missing_context` cause, and inability to resolve a dependency on that enrollment flag SHALL contribute `unresolved_dependency`. Holdouts and release conditions skipped by the enrollment check SHALL NOT contribute unresolved causes. The existing unresolved-reason precedence SHALL apply only among applicable causes; it SHALL NOT require inspecting skipped targeting to find a higher-priority reason.

Enrollment SHALL always use person properties, including when a downloaded definition uses group aggregation. When the evaluator supports retaining person context for that definition, it SHALL evaluate enrollment before requiring a group key or group properties; a missing person enrollment property SHALL contribute `missing_context`. An evaluator whose implementation cannot retain person context for that group-aggregated definition SHALL report inconclusive with the `unsupported_definition` cause rather than interpreting group properties as person enrollment. Existing reason precedence and remote-fallback/local-only rules SHALL still apply. Group aggregation alone SHALL NOT make enrollment unsupported. This does not require accepting group-based flags through the early-access feature creation API.

#### Scenario: Missing enrollment context falls back despite matching targeting (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **AND** no enrollment property is supplied locally
- **AND** the flags service returns false for the person's stored enrollment
- **WHEN** the public flag getter evaluates "beta-feature" with remote fallback enabled
- **THEN** a remote evaluation request should be made
- **AND** the returned flag value should be false

#### Scenario: Listed known-absent enrollment key resolves locally (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **AND** person property key `$feature_enrollment/beta-feature` is listed as known absent
- **AND** no enrollment property is supplied locally
- **WHEN** the public flag getter evaluates "beta-feature" with remote fallback enabled
- **THEN** the flag should resolve locally from the release condition
- **AND** no remote evaluation request should be made

#### Scenario: Local-only evaluation leaves missing enrollment and its dependency unresolved (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **AND** another active flag "dependent" requires "beta-feature" to evaluate to true
- **WHEN** a local-only snapshot is evaluated without the enrollment property
- **THEN** neither flag should have a resolved value and no remote evaluation request should be made
- **AND** their unresolved reasons should be `missing_context` and `unresolved_dependency` respectively

#### Scenario Outline: Experience continuity retains precedence over enrollment (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and experience continuity enabled
- **WHEN** a local-only snapshot is evaluated with person properties <properties>
- **THEN** the flag should remain unresolved with reason `experience_continuity`
- **AND** no remote evaluation request should be made

Examples:
| properties                                 |
| {}                                         |
| {"$feature_enrollment/beta-feature":true}  |
| {"$feature_enrollment/beta-feature":false} |

#### Scenario: Missing enrollment does not inspect unsupported release conditions (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true`, experience continuity disabled, and a static-cohort release condition the local evaluator cannot resolve
- **WHEN** a local-only snapshot is evaluated without the enrollment property
- **THEN** the flag should remain unresolved with reason `missing_context`, not `unsupported_definition`
- **AND** no remote evaluation request should be made

#### Scenario Outline: Known enrollment bypasses unsupported release conditions (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true`, experience continuity disabled, and a static-cohort release condition the local evaluator cannot resolve
- **WHEN** the flag is evaluated with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** the flag should resolve to <value> without remote evaluation

Examples:
| value |
| true  |
| false |

#### Scenario: Unsupported group enrollment reports the definition cause (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator's implementation cannot retain person context for that group-aggregated definition
- **WHEN** a local-only snapshot is evaluated with person property `$feature_enrollment/beta-feature` set to true
- **THEN** the flag should remain unresolved with reason `unsupported_definition`
- **AND** no remote evaluation request should be made

#### Scenario: Supported group enrollment does not require group context (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator supports retaining person context for that definition
- **WHEN** the flag is evaluated without a group key or group properties and with person property `$feature_enrollment/beta-feature` set to true
- **THEN** the flag should resolve to true without remote evaluation

#### Scenario: Supported group enrollment reports missing person context (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator supports retaining person context for that definition
- **AND** the matching group's enrollment property is true
- **WHEN** a local-only snapshot is evaluated without the person enrollment property
- **THEN** the flag should remain unresolved with reason `missing_context`
- **AND** no remote evaluation request should be made

#### Scenario: Group enrollment cannot override a person's opt-out (@server)
- **GIVEN** a downloaded group-aggregated definition for "beta-feature" has `feature_enrollment: true`
- **AND** the person property `$feature_enrollment/beta-feature` is false while the matching group's property is true
- **AND** remote evaluation, if needed, returns false for the person
- **WHEN** the public flag getter evaluates the flag with both person and group context
- **THEN** the returned flag value should be false

### Requirement: Numeric criteria use complete finite binary64 comparisons

For `gt`, `gte`, `lt`, and `lte`, the condition SHALL be a string matching the complete decimal grammar `[+-]?(digits[.digits*]?|.digits+)([eE][+-]?digits+)?`, where `digits` means one or more ASCII decimal digits and `digits*` means zero or more. The supplied property MAY be a JSON number or a string matching the same grammar. The evaluator SHALL convert both operands to finite IEEE-754 binary64 values and compare them in `property operator condition` order. No whitespace is trimmed. Partial parses such as `"10px"`, padded strings such as `" 10 "`, non-finite values, null, booleans, arrays, and objects SHALL NOT be accepted. The evaluator MUST NOT fall back to lexicographic or arbitrary-precision decimal comparison.

The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`.

For these four operators, a present property that cannot be converted to a finite number SHALL be a definitive no-match. An invalid condition number SHALL be inconclusive. Binary64 rounding is observable for values that cannot be represented exactly.

For dynamic-cohort property leaves, `between` SHALL accept exactly two numeric or numeric-string bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. A bound MAY be infinite, such as `"-inf"` or `"inf"`. A condition value that is not a two-element array, or that has a nonnumeric bound, a NaN bound, or `low > high`, is a malformed range. A malformed condition range SHALL be inconclusive before applying any cohort leaf `negation`.

The range operators follow HogQL, which reads a property value that does not convert to a number as NULL. For these operators, a property string converts to a number when it matches the decimal grammar of the numeric ordering operators or is `inf`, `infinity`, or `nan` in any letter case with an optional sign. A supplied property that is null, a boolean, an array, an object, or a string that does not convert SHALL NOT match `between` and SHALL match `not_between`. A property that converts to NaN SHALL match neither operator. A property that converts to positive or negative infinity SHALL compare as that infinity. An absent property key follows the missing-context rule of the operator inventory: it is inconclusive unless the key is listed as known absent.

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
  | `between` | `[10, 20]` | `"not-a-number"` | false |
  | `not_between` | `[10, 20]` | `"not-a-number"` | true |
  | `not_between` | `[10, 20]` | `null` | true |
  | `between` | `[10, 20]` | `"NaN"` | false |
  | `not_between` | `[10, 20]` | `"NaN"` | false |
  | `between` | `[10, 20]` | `"inf"` | false |
  | `not_between` | `[10, 20]` | `"inf"` | true |
  | `between` | `["-inf", "inf"]` | `0` | true |
  | `between` | `[20, 10]` | `15` | inconclusive |
  | `not_between` | `[10]` | `15` | inconclusive |
  | `between` | `["NaN", 20]` | `15` | inconclusive |

#### Scenario: Cohort negation does not invert a malformed range (@server)
- **GIVEN** a dynamic cohort leaf has condition `between [1,2,3]`
- **AND** the leaf sets `negation` to true
- **WHEN** it is evaluated against property `2`
- **THEN** the cohort leaf should be inconclusive
- **AND** negation should not turn it into a match

## ADDED Requirements

### Requirement: Remote fallback carries known-absent keys

When local evaluation falls back to the `/flags` endpoint and the evaluation had a known-absence input, the SDK SHALL send the same known-absent keys in the request body so that local and remote results agree. The SDK SHALL send `person_property_keys_known_absent` as an array of person property key strings. It SHALL send `group_property_keys_known_absent` as an object mapping a group type name to an array of group property key strings. An SDK SHALL omit a field, or send JSON null, when it has nothing to list.

The flags service treats both fields as optional. A missing or null field means nothing is listed, and requests without them behave as before. Each array holds at most 1000 strings, counted with duplicates and counted per group type for the group field. A field of the wrong type, or an array longer than that, returns HTTP 400 with a message that names the field. Group type names that the project does not have are ignored. A key that the flags service is told is absent is absent for that evaluation even when the request also supplies a value for it in `person_properties` or `group_properties`, and even when the service would otherwise use a stored value or a value it adds itself, such as GeoIP `$geoip_*` properties, `$initial_*` properties copied from a non-initial key, the `$os` and `$os_name` alias, `$group_key`, and `distinct_id`. Operator results follow the canonical operator inventory requirement. Known absence does not change static or realtime cohort membership, which the service reads from stored tables.

An SDK SHALL NOT send a known-absence field that was not part of the caller's input. An SDK SHOULD validate the 1000-key limit before the request so the caller gets a local error instead of a failed fallback, and SHALL NOT silently truncate a list.

#### Scenario: Remote fallback sends the listed person keys
- **GIVEN** remote feature flag evaluation is enabled
- **AND** a local flag is inconclusive for another reason
- **WHEN** the flag is evaluated with person property key "plan" listed as known absent
- **THEN** the `/flags` request body should include `person_property_keys_known_absent` equal to `["plan"]`

#### Scenario: Remote fallback sends the listed group keys by group type
- **GIVEN** remote feature flag evaluation is enabled
- **AND** a local flag is inconclusive for another reason
- **WHEN** the flag is evaluated with group property key "tier" listed as known absent for group type "organization"
- **THEN** the `/flags` request body should include `group_property_keys_known_absent` equal to `{"organization": ["tier"]}`

#### Scenario: Requests without a known-absence input omit the fields
- **GIVEN** remote feature flag evaluation is enabled
- **WHEN** a flag is evaluated with no known-absent keys
- **THEN** the `/flags` request body should not require either known-absence field
