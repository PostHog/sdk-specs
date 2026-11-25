## MODIFIED Requirements

### Requirement: Per-condition aggregation selects property context and bucketing identity

A condition group MAY select its own aggregation with `aggregation_group_type_index`. When the field is absent from the condition, the evaluator SHALL inherit the flag-level aggregation for backwards compatibility. When the field is present with a null value, the condition SHALL explicitly use person aggregation. When it contains a group type index, the condition SHALL use that group aggregation even when it differs from the flag-level value.

Person conditions SHALL use person properties, and group conditions SHALL use properties for their selected group type. Cohort filters SHALL use person context, while flag-dependency filters SHALL use dependency results. All filters in the condition SHALL match before rollout is applied.

A filter with property type `group` that omits `group_type_index` SHALL read the group type of the condition's effective aggregation, as the flags service does. That group type's properties and its known-absent keys SHALL apply to the filter. A filter that sets `group_type_index` SHALL read that group type, and the known-absent keys of another group type SHALL NOT apply to it.

The condition's effective aggregation SHALL choose the identifier for its rollout and multivariate hashes. A person-aggregated condition SHALL use the flag's person bucketing identifier (`distinct_id` by default or the required device id for device-bucketed flags). A group-aggregated condition SHALL use the selected group key and SHALL NOT switch to device-id bucketing. Variant assignment after a match SHALL use the same effective aggregation as that matching condition.

A group-aggregated condition whose group type has no key in the supplied groups SHALL NOT match, as the flags service skips it with the `NoGroupType` reason. This is a definitive non-match, not missing context, so a flag whose conditions are all skipped this way SHALL resolve as `false` locally without remote fallback, whether it is evaluated directly or as a dependency. A supplied group key that is not a string or number, or a supplied group key without the group properties a condition needs, is not a missing key: those cases SHALL follow the inconclusive rules below.

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

#### Scenario: A group filter without a group type index reads the condition's group type (@server)
- **GIVEN** a flag has flag-level aggregation for group type "organization"
- **AND** its condition has a group property filter on "tier" that omits `group_type_index`
- **WHEN** the flag is evaluated locally for organization "acme" with group property "tier" set to "enterprise" and group property key "tier" listed as known absent for group type "organization"
- **THEN** the filter should treat "tier" as known absent for group type "organization"
- **AND** an `exact` "enterprise" filter should not match
- **AND** an `is_not_set` filter should match
- **AND** remote evaluation should not be required

#### Scenario: A device-bucketed person flag without a device id is inconclusive (@server)
- **GIVEN** a device-bucketed flag has only person-aggregated conditions
- **WHEN** the flag is evaluated locally without a device id
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled
### Requirement: Flag dependency filters compare evaluated flag values

A condition filter with property type `flag` SHALL use the `flag_evaluates_to` operator and compare its expected value with the referenced flag's evaluated value. Expected boolean `true` SHALL match boolean `true` and any multivariate variant string, but SHALL NOT match boolean `false`. Expected boolean `false` SHALL match only boolean `false`. An expected string SHALL match only the identical multivariate variant string, using a case-sensitive comparison.

Dependency filters SHALL be ANDed with every other filter in their condition. A dependency filter's `key` SHALL identify the referenced feature-flag key.

A missing definition, unresolved dependency, or cycle SHALL make the dependent flag locally inconclusive and eligible for remote fallback. An inactive or filtered referenced definition remains resolvable as boolean `false`: a dependency expecting `false` matches definitively, while one expecting `true` definitively does not match.

The evaluator SHALL evaluate a referenced flag as if it were evaluated directly with the same inputs: the same distinct id, groups, person properties, group properties, and known-absent keys. The referenced flag SHALL use its own aggregation, so its conditions read the property context and bucketing identifier that its definition selects, not those of the condition that references it. A referenced flag aggregated by a group type absent from the supplied groups SHALL resolve as `false`, as the flags service resolves it. The dependency filter SHALL compare only that evaluated value. The flags service does the same: it evaluates flags in dependency order, each with the full request context, and a dependency filter reads the stored result.

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

#### Scenario: A dependency is evaluated with its own aggregation (@server)
- **GIVEN** flag "org-parent" has flag-level aggregation for group type "organization" and requires group property "region" equal to "us"
- **AND** person-aggregated flag "person-child" requires "org-parent" to evaluate to true
- **WHEN** "person-child" is evaluated locally for organization "acme" with person property "region" set to "us" and group property "region" set to "eu"
- **THEN** "org-parent" should evaluate to false from the organization properties
- **AND** the local evaluation result for "person-child" should be false
- **AND** remote evaluation should not be required

#### Scenario: A group dependency without its group resolves as false (@server)
- **GIVEN** flag "org-parent" has flag-level aggregation for group type "organization" and requires group property "tier" with operator `is_not_set`
- **AND** person-aggregated flag "person-child" requires "org-parent" to evaluate to true
- **WHEN** "person-child" is evaluated locally without an "organization" group and with group property key "tier" listed as known absent for group type "organization"
- **THEN** "org-parent" should evaluate to false
- **AND** the local evaluation result for "person-child" should be false
- **AND** remote evaluation should not be required

#### Scenario: An inactive dependency resolves as false (@server)
- **GIVEN** inactive flag `A` is retained as a dependency of active flags `B` and `C`
- **AND** `B` expects `A` to evaluate to false
- **AND** `C` expects `A` to evaluate to true
- **WHEN** `B` and `C` are evaluated locally
- **THEN** the dependency criterion for `B` should match
- **AND** the dependency criterion for `C` should not match

### Requirement: Canonical local-feature-flag-evaluator behavior

The SDK SHALL implement the canonical `local-feature-flag-evaluator` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Evaluator returns true for a matching active boolean flag
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "beta-ui" rolled out to distinct id "user-123"
- **WHEN** local feature flag "beta-ui" is evaluated for distinct id "user-123"
- **THEN** the local evaluation result should be true

#### Scenario: Evaluator returns a variant for a matching multivariate flag
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a multivariate flag "checkout" with variant "blue" for distinct id "user-123"
- **WHEN** local feature flag "checkout" is evaluated for distinct id "user-123"
- **THEN** the local evaluation result should be "blue"

#### Scenario: Evaluator resolves a group flag without its group key as false
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** remote feature flag evaluation is enabled
- **AND** local feature flag definitions include a group flag "company-beta" for group type "company"
- **WHEN** local feature flag "company-beta" is evaluated without a "company" group
- **THEN** the local evaluation result should be false
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123"
- **THEN** no remote feature flag evaluation request should be sent for flag "company-beta"

#### Scenario: Evaluator signals remote fallback when required group properties are missing
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** remote feature flag evaluation is enabled
- **AND** local feature flag definitions include a group flag "company-beta" for group type "company" that requires company property "tier"
- **WHEN** local feature flag "company-beta" is evaluated for company "acme" without company properties
- **THEN** local evaluation should be inconclusive
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" and company "acme"
- **THEN** a remote feature flag evaluation request should be sent for flag "company-beta"

#### Scenario: Evaluator resolves payload from the matched value
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a multivariate flag "checkout" with variant "blue" and payload:
  | field | value |
  | copy  | new   |
- **WHEN** local feature flag "checkout" is evaluated for distinct id "user-123"
- **THEN** the local evaluation payload should include:
  | field | value |
  | copy  | new   |
