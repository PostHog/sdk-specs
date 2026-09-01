## ADDED Requirements

### Requirement: Condition groups are selected as ordered alternatives

For feature-flag definitions that contain condition groups, the local evaluator SHALL evaluate the groups in their definition order. All property, cohort, and flag-dependency filters within one group SHALL be combined with logical AND. The groups themselves SHALL be alternatives: a group that does not match SHALL NOT prevent evaluation of the next group. A group with no filters SHALL proceed directly to its rollout gate.

After every filter in a group matches, the evaluator SHALL apply that group's `rollout_percentage`, defaulting an absent percentage to `100.0`. The first group whose filters match and whose rollout includes the effective bucketing identifier SHALL determine the flag value. The evaluator MUST NOT reorder groups to prioritize condition-level variant overrides.

For a matching multivariate condition, a condition-level `variant` SHALL be used only when it names one of the flag's defined variants. If the override is absent or invalid, the evaluator SHALL select a variant with the normal deterministic variant hash. A matching non-multivariate condition SHALL return `true`.

The flag-level `early_exit` selector SHALL default to `false`. When it is `true`, the evaluator SHALL return `false` immediately, with no variant or payload, only when every filter in the current group matched but that group's rollout excluded the effective bucketing identifier. A property, cohort, or dependency mismatch SHALL continue to the next group and SHALL NOT trigger `early_exit`. A locally inconclusive group SHALL also not itself trigger `early_exit`; the evaluator SHALL continue so another independently evaluable group can match. If no later group matches and at least one group was inconclusive, the flag SHALL remain inconclusive even when other groups definitively do not match.

#### Scenario: The first matching condition wins without variant-priority sorting (@server)
- **GIVEN** a multivariate flag has a first condition that matches person property "plan" equal to "pro" with no variant override
- **AND** the same flag has a later catch-all condition overriding the variant to "test"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally for a person whose "plan" is "pro"
- **THEN** the local evaluation result should be "control"
- **AND** the later "test" override should not reorder or replace the first matching condition

#### Scenario: Filters are ANDed within a condition and conditions are ORed (@server)
- **GIVEN** a flag's first condition requires person property "plan" equal to "pro" and person property "region" equal to "us"
- **AND** its second condition requires only person property "plan" equal to "pro"
- **WHEN** the flag is evaluated locally with person properties "plan" equal to "pro" and "region" equal to "eu"
- **THEN** the first condition should not match
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Early exit stops after a targeted rollout exclusion (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first condition matches person property "plan" equal to "pro" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the local evaluation result should be false
- **AND** the result should not include a variant or payload
- **AND** the second condition should not be evaluated as a match

#### Scenario: Disabled early exit allows a later condition to match (@server)
- **GIVEN** a flag omits `early_exit` or sets it to false
- **AND** its first condition matches person property "plan" equal to "pro" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the local evaluation result should be true from the second condition

#### Scenario: Early exit does not stop after a property mismatch (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first condition requires person property "plan" equal to "enterprise" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the first condition should be treated as a property mismatch rather than a rollout exclusion
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Early exit does not stop after an inconclusive condition (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first group-aggregated condition has an available group key but missing required group properties and rollout percentage `0.0`
- **AND** its second person-aggregated condition matches person property "plan" equal to "pro" with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the first condition should remain inconclusive and should not trigger `early_exit`
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Inconclusive state is preserved when no later condition matches (@server)
- **GIVEN** a flag's first condition cannot be resolved from the supplied local context
- **AND** every later condition definitively does not match
- **WHEN** the flag is evaluated locally
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible

#### Scenario: A valid condition variant override wins (@server)
- **GIVEN** a multivariate flag defines variants "control" and "test"
- **AND** its first matching condition specifies variant override "test"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be "test"

#### Scenario: An invalid condition variant override falls back to deterministic assignment (@server)
- **GIVEN** a multivariate flag defines variants "control" and "test"
- **AND** its first matching condition specifies variant override "unknown"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be "control"

### Requirement: Per-condition aggregation selects property context and bucketing identity

A condition group MAY select its own aggregation with `aggregation_group_type_index`. When the field is absent from the condition, the evaluator SHALL inherit the flag-level aggregation for backwards compatibility. When the field is present with a null value, the condition SHALL explicitly use person aggregation. When it contains a group type index, the condition SHALL use that group aggregation even when it differs from the flag-level value.

Person conditions SHALL use person properties, and group conditions SHALL use properties for their selected group type. Cohort filters SHALL use person context, while flag-dependency filters SHALL use dependency results. All filters in the condition SHALL match before rollout is applied.

The condition's effective aggregation SHALL choose the identifier for its rollout and multivariate hashes. A person-aggregated condition SHALL use the flag's person bucketing identifier (`distinct_id` by default or the required device id for device-bucketed flags). A group-aggregated condition SHALL use the selected group key and SHALL NOT switch to device-id bucketing. Variant assignment after a match SHALL use the same effective aggregation as that matching condition.

If context required by one condition cannot be resolved locally, the evaluator SHALL apply the existing inconclusive/remote-fallback rules for that condition without preventing another independently evaluable condition from matching.

#### Scenario: An omitted condition aggregation inherits the legacy flag aggregation (@server)
- **GIVEN** a flag has flag-level aggregation for group type "company"
- **AND** its condition omits `aggregation_group_type_index`
- **AND** the condition requires company property "tier" equal to "enterprise"
- **WHEN** the flag is evaluated locally for company "acme" with company property "tier" equal to "enterprise"
- **THEN** the condition should match using the flag-level company aggregation

#### Scenario: Explicit person aggregation overrides a flag-level group aggregation (@server)
- **GIVEN** a flag has flag-level aggregation for group type "company"
- **AND** its condition sets `aggregation_group_type_index` to null
- **AND** the condition requires person property "plan" equal to "pro"
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the condition should match using person context and person bucketing

#### Scenario: The matching condition selects the multivariate hash identity (@server)
- **GIVEN** a multivariate flag has a group-aggregated condition followed by a person-aggregated condition
- **AND** the group condition cannot be resolved from the supplied group context
- **AND** the person condition matches
- **AND** the person's bucketing identifier hashes to variant "control"
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be "control"
- **AND** variant assignment should use the person identifier from the matching condition rather than a group key

#### Scenario: Missing device id blocks only person-aggregated conditions (@server)
- **GIVEN** a device-bucketed flag has a person-aggregated condition followed by a group-aggregated condition
- **AND** no device id is supplied
- **AND** the required group key is supplied and the group condition matches
- **WHEN** the flag is evaluated locally
- **THEN** the group condition should determine the local evaluation result
- **AND** the person condition should not fall back to hashing the distinct id

#### Scenario: A device-bucketed person flag without a device id is inconclusive (@server)
- **GIVEN** a device-bucketed flag has only person-aggregated conditions
- **WHEN** the flag is evaluated locally without a device id
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

### Requirement: Flag dependency filters compare evaluated flag values

A condition filter with property type `flag` SHALL use the `flag_evaluates_to` operator and compare its expected value with the referenced flag's evaluated value. Expected boolean `true` SHALL match boolean `true` and any multivariate variant string, but SHALL NOT match boolean `false`. Expected boolean `false` SHALL match only boolean `false`. An expected string SHALL match only the identical multivariate variant string, using a case-sensitive comparison.

Dependency filters SHALL be ANDed with every other filter in their condition. A dependency filter's `key` SHALL identify the referenced feature-flag key.

A missing definition, unresolved dependency, or cycle SHALL make the dependent flag locally inconclusive and eligible for remote fallback. An inactive or filtered referenced definition remains resolvable as boolean `false`: a dependency expecting `false` matches definitively, while one expecting `true` definitively does not match.

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

#### Scenario: An unresolved dependency is inconclusive (@server)
- **GIVEN** flag "banner" depends on a flag definition that is missing or cannot be resolved locally
- **WHEN** "banner" is evaluated locally
- **THEN** local evaluation should be inconclusive for "banner"
- **AND** remote evaluation should remain eligible

#### Scenario: An inactive dependency resolves as false (@server)
- **GIVEN** inactive flag `A` is retained as a dependency of active flags `B` and `C`
- **AND** `B` expects `A` to evaluate to false
- **AND** `C` expects `A` to evaluate to true
- **WHEN** `B` and `C` are evaluated locally
- **THEN** the dependency criterion for `B` should match
- **AND** the dependency criterion for `C` should not match
