## MODIFIED Requirements

### Requirement: Per-condition aggregation selects property context and bucketing identity

A condition group MAY select its own aggregation with `aggregation_group_type_index`. When the field is absent from the condition, the evaluator SHALL inherit the flag-level aggregation for backwards compatibility. When the field is present with a null value, the condition SHALL explicitly use person aggregation. When it contains a group type index, the condition SHALL use that group aggregation even when it differs from the flag-level value.

Person conditions SHALL use person properties, and group conditions SHALL use properties for their selected group type. Cohort filters SHALL use person context, while flag-dependency filters SHALL use dependency results. All filters in the condition SHALL match before rollout is applied.

A filter with property type `group` that omits `group_type_index` SHALL read the group type of the condition's effective aggregation, as the flags service does. That group type's properties and its known-absent keys SHALL apply to the filter. A filter that sets `group_type_index` SHALL read that group type, and the known-absent keys of another group type SHALL NOT apply to it.

The condition's effective aggregation SHALL choose the identifier for its rollout and multivariate hashes. A person-aggregated condition SHALL use the flag's person bucketing identifier (`distinct_id` by default or the required device id for device-bucketed flags). A group-aggregated condition SHALL use the selected group key and SHALL NOT switch to device-id bucketing. Variant assignment after a match SHALL use the same effective aggregation as that matching condition.

A condition whose effective aggregation is a group type with no usable key in the supplied groups SHALL NOT match, as the flags service skips it with the `NoGroupType` reason. A usable group key is a non-empty JSON string or a JSON number, as the flags service's `is_usable_group_key` defines it. An omitted group type, an empty string, JSON null, a boolean, an array, or an object SHALL count as no key. The evaluator SHALL check each condition against its own effective aggregation: a condition that sets `aggregation_group_type_index` uses that value (null means person), and a condition that omits it uses the flag-level aggregation. A skipped condition is a definitive non-match, not missing context, and the evaluator SHALL continue with the remaining conditions, so a person-aggregated condition still evaluates when the flag-level group has no usable key. The evaluator SHALL NOT resolve a flag as `false` from its flag-level aggregation alone. A flag SHALL resolve as `false` locally without remote fallback only when no condition matches and none is inconclusive. This applies the same way whether the flag is evaluated directly or as a dependency. A usable group key supplied without the group properties a condition needs is not a missing key: that case SHALL follow the inconclusive rules below.

A holdout is checked before the conditions and uses the flag-level bucketing identity. When a flag has a complete holdout whose clamped `exclusion_percentage` is above 0, and its flag-level aggregation is a group type with no usable key in the supplied groups, the evaluator SHALL report the flag inconclusive with the `missing_context` cause. Remote fallback SHALL remain eligible, and local-only evaluation SHALL leave the flag unresolved. The flags service hashes an empty identifier for that holdout and may return `holdout-<id>`, so a local `false` could disagree with it. The evaluator SHALL NOT compute a holdout hash for an unusable key. A flag without a holdout, with an exclusion percentage of 0, or with a usable flag-level group key SHALL be evaluated as described above.

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

#### Scenario: A person condition matches without the flag-level group key (@server)
- **GIVEN** flag "company-mixed" has flag-level aggregation for group type "company"
- **AND** its only condition sets `aggregation_group_type_index` to null and requires person property "plan" equal to "pro"
- **AND** person-aggregated flag "person-child" requires "company-mixed" to evaluate to true
- **WHEN** "company-mixed" is evaluated locally with person property "plan" equal to "pro" and without a "company" group
- **THEN** the local evaluation result should be true
- **AND** remote evaluation should not be required
- **WHEN** "person-child" is evaluated locally with the same inputs
- **THEN** "company-mixed" should evaluate to true
- **AND** the local evaluation result for "person-child" should be true
- **AND** remote evaluation should not be required

#### Scenario: A holdout without a usable flag-level group key is inconclusive (@server)
- **GIVEN** a group flag "company-beta" for group type "company" would return true with a usable group key
- **AND** it has holdout id 727 with exclusion percentage 50
- **WHEN** "company-beta" is evaluated locally without a "company" group
- **THEN** local evaluation should be inconclusive
- **AND** the unresolved reason should be `missing_context`
- **AND** remote evaluation should remain eligible

#### Scenario Outline: A holdout that needs no group key leaves a group flag unchanged (@server)
- **GIVEN** a group flag "company-beta" for group type "company" would return true with a usable group key
- **AND** it has holdout id 727 with exclusion percentage <percentage>
- **WHEN** "company-beta" is evaluated locally with group "company" set to <key>
- **THEN** the local evaluation result should be <result>
- **AND** remote evaluation should not be required

  | percentage | key | result | note |
  | 0 | an empty string | false | a 0% holdout needs no key, and the only condition is skipped |
  | 50 | the string "acme" | true | the holdout hash for "acme" is about 0.9269703562845474, above 0.5 |

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

#### Scenario: An index-less group filter follows the condition's aggregation over the flag's (@server)
- **GIVEN** a flag has flag-level aggregation for group type "project"
- **AND** its condition sets `aggregation_group_type_index` to group type "organization"
- **AND** the condition has a group property filter on "tier" that omits `group_type_index`
- **WHEN** the flag is evaluated locally for project "web" and organization "acme", both with group property "tier" set to "enterprise", and with group property key "tier" listed as known absent for group type "organization" only
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

The evaluator SHALL evaluate a referenced flag as if it were evaluated directly with the same inputs: the same distinct id, groups, person properties, group properties, and known-absent keys. The referenced flag SHALL use its own aggregation, so its conditions read the property context and bucketing identifier that its definition selects, not those of the condition that references it. The dependency filter SHALL compare only that evaluated value. The flags service does the same: it evaluates flags in dependency order, each with the full request context, and a dependency filter reads the stored result.

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

#### Scenario: A dependency on a matching group flag reads the group's properties (@server)
- **GIVEN** flag "org-parent" has flag-level aggregation for group type "organization" and requires group property "region" equal to "us"
- **AND** person-aggregated flag "person-child" requires "org-parent" to evaluate to true
- **WHEN** "person-child" is evaluated locally for organization "acme" with person property "region" set to "eu" and group property "region" set to "us"
- **THEN** "org-parent" should evaluate to true from the organization properties
- **AND** the local evaluation result for "person-child" should be true
- **AND** remote evaluation should not be required

#### Scenario: A dependency whose only condition needs a missing group key resolves as false (@server)
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

#### Scenario: Evaluator resolves a flag whose only condition needs a missing group key as false
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** remote feature flag evaluation is enabled
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
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

### Requirement: Group keys are rendered for bucketing like the flags service

A group key reaches the evaluator through an untyped map, so it is not necessarily a string. Before using the selected group key as a bucketing identifier, the evaluator SHALL render it with the same canonical representation the flags service uses for `hashed_identifier`: a JSON string contributes its unquoted contents, and a JSON number contributes its canonical JSON encoding, the same bytes the SDK would send to `/flags` for that key. A numeric group key SHALL therefore bucket identically whether the flag is evaluated locally or remotely. Where the host runtime collapses distinct numeric kinds, the limitation already described by the backend-compatible property-filter stringification requirement applies unchanged.

An empty string and a group key of any other type, such as JSON null, a boolean, an array, or an object, are not usable group keys. The evaluator SHALL treat the group as not supplied, as the per-condition aggregation requirement defines: a condition whose effective aggregation is that group type SHALL NOT match, the remaining conditions still evaluate, and a flag with a holdout that needs the key is inconclusive. The evaluator SHALL NOT render such a key with a host-specific spelling or use it as a bucketing identifier.

Scenarios that pass a JSON null, a boolean, an array, or an object as a group key are labeled `@json_group_keys_capable`. They apply only to an SDK whose API can pass such a value as a group key.

An unusable group key SHALL NOT crash, panic, or raise out of any caller-facing surface that evaluates flags locally, including single-flag and bulk evaluation and a capture call that evaluates flags as a side effect.

#### Scenario: A numeric group key buckets like its decimal form (@server)
- **GIVEN** a group-aggregated flag with a partial rollout percentage
- **AND** group "company" is supplied with the number 42
- **WHEN** the flag is evaluated locally
- **THEN** the bucketing identifier should be "42"
- **AND** the local evaluation result should equal the result for group "company" supplied as the string "42"

#### Scenario: A numeric group key does not crash a capture that evaluates flags (@server)
- **GIVEN** local evaluation is enabled and a group-aggregated flag exists
- **AND** group "company" is supplied with the number 42
- **WHEN** an event is captured with feature flag evaluation enabled
- **THEN** the capture should complete without raising

#### Scenario Outline: An unusable group key counts as no group (@server)
- **GIVEN** a group flag "company-beta" for group type "company" that returns true with a usable group key
- **AND** group "company" is supplied with <key>
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be <result>
- **AND** no remote flag evaluation request should be made

  | key | result |
  | an empty string | false |
  | the string "acme" | true |

#### Scenario Outline: A non-string group key counts as no group (@server @json_group_keys_capable)
- **GIVEN** a group flag "company-beta" for group type "company" that returns true with a usable group key
- **AND** group "company" is supplied with <key>
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be false
- **AND** no remote flag evaluation request should be made

  | key |
  | JSON null |
  | the boolean true |
  | an array |
  | an object |
