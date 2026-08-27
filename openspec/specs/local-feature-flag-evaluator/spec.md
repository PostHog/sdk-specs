# Local Feature Flag Evaluator Specification

## Purpose

`local-feature-flag-evaluator` is the internal engine that computes feature-flag values from **locally available flag definitions and evaluation context**, without requiring a round trip to PostHog for every lookup.

It exists to:

- evaluate flags from cached/polled definitions
- resolve multivariate variants and payloads locally
- decide when local evaluation is impossible or inconclusive
- signal when the SDK must fall back to server-side evaluation

## Applicability

`both` — local evaluation exists in both client-style and server-style SDKs, though it is most prominent in server SDKs that poll feature-flag definitions and evaluate per request. Some client wrappers, such as Flutter, do not own a separate evaluator and instead delegate evaluation to underlying native/browser SDKs.

## Public signature(s)

No single public API.

Typical internal operations look like:

```ts
computeFlagLocally(flag, distinctId, context): FeatureFlagValue | throws Inconclusive
computeFlagAndPayloadLocally(flag, context): { value, payload }
evaluateAllFlags(context): { results, fallbackToRemote }
```

## Behavior

1. **Load local flag definitions first.** The evaluator needs a current in-memory set of feature-flag definitions, group-type mappings, cohort data, and payload definitions.
2. **Build an evaluation context.** Inputs commonly include:
   - `distinct_id`
   - groups
   - person properties
   - group properties
   - device id / bucketing value
   - dependency evaluation cache
3. **Short-circuit inactive flags.** Disabled flags return `false` locally.
4. **Handle group-scoped flags specially.** If the flag targets a group aggregation index, evaluate it against the matching group key/properties instead of person properties.
5. **Resolve bucketing value.** Use `distinct_id` by default, or `device_id` when the flag's bucketing mode requires it.
6. **Match flag conditions locally.** Evaluate property filters, rollout percentages, multivariate overrides, and dependency chains using local definitions. See "String prefix/suffix property filter operators" below for the `starts_with`/`ends_with` family.
7. **Return either a boolean or variant string.** Multivariate flags resolve to a variant key; boolean flags resolve to `true` / `false`.
8. **Resolve payload from the chosen value.** Payload lookup uses the computed match value (or an explicitly supplied override match value in some SDKs).
9. **Signal fallback when local evaluation is impossible.** If required context is missing, a dependency cannot be resolved, a feature uses unsupported behavior (for example experience continuity / static cohorts), or the evaluator cannot reach a conclusive answer, it raises/returns an "inconclusive" / "requires server evaluation" signal.
10. **Allow higher layers to fall back to remote evaluation.** The evaluator itself should not silently invent results when the local state is insufficient.
11. **Allow wrapper SDKs to proxy evaluation into another SDK.** Some wrappers expose feature-flag getters without owning their own rule engine. Flutter's Dart layer forwards `isFeatureEnabled(...)`, `getFeatureFlag(...)`, `getFeatureFlagPayload(...)`, `getFeatureFlagResult(...)`, and `reloadFeatureFlags()` to the underlying native/browser SDKs, so local-evaluation semantics and readiness remain owned by those platform SDKs rather than a separate Dart evaluator.

## State & lifecycle

### State read

- locally cached flag definitions
- group-type mapping
- local cohort data where available
- cached dependency evaluation results for the current computation
- optional device id / bucketing metadata

### State written

Usually none directly, except temporary evaluation-cache state created for the current evaluation pass.

### Lifecycle behavior

- Definitions are loaded/polled separately, then reused by this evaluator.
- The evaluator is invoked on each flag lookup or bulk local evaluation request.
- When definitions change, future evaluations use the new rules without changing caller APIs.
- Wrapper SDKs can inherit this lifecycle from another implementation instead of managing it directly. Flutter's `reloadFeatureFlags()` and flag-getter methods re-enter the native/browser SDKs for reload/evaluation work rather than advancing a separate Dart-owned evaluator lifecycle.

## Error handling

- Local evaluation should not crash application code.
- Unsupported or inconclusive cases are surfaced as dedicated "fall back to server" / "inconclusive" signals rather than generic crashes.
- Invalid user input or malformed flag definitions are often treated as inconclusive rather than returning a wrong result.
- Higher layers usually catch these signals and decide whether to return `undefined`, `false`, or fetch remotely.
- An unrecognized property-filter operator is one such inconclusive case — see "Unrecognized property-filter operators degrade to inconclusive" below.

## Concurrency & ordering guarantees

- A single local evaluation pass is deterministic for a fixed definition set and evaluation context.
- Dependency evaluation caches prevent infinite recursion and repeated work during one evaluation pass.
- Shared definition stores may be updated concurrently by pollers, so callers can observe old or new definitions depending on timing, but not a partially-mutated single flag evaluation result.

## Interactions

- **feature-flag-cache** supplies the local definitions/values/payload data that enable local evaluation.
- **get-feature-flag / get-feature-flag-result / is-feature-enabled** call into this evaluator before deciding whether to fall back to remote evaluation.
- **http-client** is used only when the evaluator reports that server evaluation is required or local evaluation is unavailable.
- **device-id-generator** may provide the device id used for device-based bucketing.
- **wrapper SDK surfaces** may proxy only part of the evaluation-context controls. Flutter forwards flag reads/reloads to the underlying SDKs but does not expose standalone Dart APIs for person/group local-override setters, so the effective local-evaluation context comes from the delegated platform SDK state rather than a separate Dart override layer.

## Requirements

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

#### Scenario: Evaluator signals remote fallback when required context is missing
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** remote feature flag evaluation is enabled
- **AND** local feature flag definitions include a group flag "company-beta" for group type "company"
- **WHEN** local feature flag "company-beta" is evaluated without group context
- **THEN** local evaluation should be inconclusive
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123"
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

### Requirement: String prefix/suffix property filter operators

When a local feature-flag definition contains a `starts_with`, `not_starts_with`, `ends_with`, or `not_ends_with` property operator, the local evaluator SHALL apply the canonical string-criterion behavior defined by this spec. Matching SHALL stringify both scalar operands, lowercase them using at least ASCII case-folding, and compare with a prefix check or suffix check, negating only a valid comparison for the `not_*` variants.

At reference commit `935b7683660697bdc75c042c4c56828aeb036754`, these four operators are SDK-local compatibility extensions: they are not members of the Rust feature-flags service's `OperatorType` and are not accepted by the direct feature-flag API allowlist. This requirement therefore defines how an SDK SHALL interpret such an operator if it receives one; it does not claim that the audited server can author or remotely evaluate these operators.

When the property required for evaluation is absent from the supplied partial context, matching SHALL be inconclusive and eligible for remote fallback under the evaluator's ordinary unknown/unsupported-definition behavior.

#### Scenario: A starts_with filter matches locally (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with property "email"
  equal to "Admin@Example.com"
- **THEN** the local evaluation result should be true

#### Scenario: A starts_with filter is inconclusive when the property is missing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with no "email" property
- **THEN** local evaluation should be inconclusive

### Requirement: is_set and is_not_set distinguish property presence from unavailable context

The local evaluator SHALL match an `is_set` property filter whenever the required evaluation property key is present. A property explicitly supplied with the platform's JSON null equivalent SHALL match `is_set`, because the key is present.

Boolean false, numeric zero, an empty string, and empty collections SHALL also count as set. Implementations SHALL test property membership and SHALL NOT use generic language truthiness or a non-null check to decide whether a property is set.

When the required property key is absent from caller-supplied local evaluation context, `is_set` SHALL remain inconclusive and defer to remote evaluation when remote fallback is enabled. Omission from request-time properties does not prove that the property is absent from PostHog's stored person or group properties.

The local evaluator SHALL definitively not match an `is_not_set` property filter whenever the required evaluation property key is present, including when its value is null or another falsey value. When the key is absent from caller-supplied local evaluation context, `is_not_set` SHALL remain inconclusive and SHALL NOT match solely because the key was omitted.

Caller-supplied property maps therefore represent present values or unavailable context; they do not currently represent affirmative knowledge that a property is absent. A definitive `is_not_set` match requires property context known to be complete or an explicit known-absence input. Adding such an input requires a separate SDK evaluation option and corresponding `/flags` request contract and is outside this requirement.

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

#### Scenario: Missing property context leaves is_not_set inconclusive
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

### Requirement: Unrecognized property-filter operators degrade to inconclusive

The local evaluator SHALL treat any property-filter operator string it does not recognize as
inconclusive for that flag — deferring to remote evaluation for that flag only — rather than
raising an unhandled error. This includes, for example, a new server-side operator not yet
supported by that SDK's evaluator. This inconclusive signal SHALL NOT disable or interrupt local
evaluation of other flags in the same evaluation pass; only the flag using the unrecognized
operator falls back to remote evaluation.

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

### Requirement: Fractional rollout percentages

The local evaluator SHALL treat a flag condition group's `rollout_percentage` as a
floating-point number, not an integer. It MUST NOT truncate or round `rollout_percentage`
before comparing it against a distinct id's bucketing hash — truncating a fractional value such
as `0.1` toward zero (or rounding it) can move users into or out of the rollout bucket
incorrectly. An absent `rollout_percentage` SHALL be treated as an unbounded rollout (matches
every distinct id), and `0.0` / `100.0` SHALL behave as the exclusive lower and inclusive upper
bounds respectively, exactly as they did before any given SDK widened the field's numeric type.

#### Scenario: A fractional rollout percentage matches only the intended bucket
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "fractional-rollout" with rollout
  percentage "0.1"
- **WHEN** local feature flag "fractional-rollout" is evaluated for a distinct id whose bucketing
  hash falls inside the 0.1% bucket
- **THEN** the local evaluation result should be true
- **WHEN** local feature flag "fractional-rollout" is evaluated for a distinct id whose bucketing
  hash falls outside the 0.1% bucket
- **THEN** the local evaluation result should be false

#### Scenario: Rollout percentage boundaries keep behaving after widening to a float
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "boundary-rollout" with rollout
  percentage "100.0"
- **WHEN** local feature flag "boundary-rollout" is evaluated for any distinct id
- **THEN** the local evaluation result should be true
- **GIVEN** local feature flag definitions include a flag "zero-rollout" with rollout
  percentage "0.0"
- **WHEN** local feature flag "zero-rollout" is evaluated for any distinct id
- **THEN** the local evaluation result should be false

### Requirement: Condition groups are selected as ordered alternatives

For feature-flag definitions that contain condition groups, the local evaluator SHALL evaluate the groups in their definition order. All property, cohort, and flag-dependency filters within one group SHALL be combined with logical AND. The groups themselves SHALL be alternatives: a group that does not match SHALL NOT prevent evaluation of the next group. A group with no filters SHALL proceed directly to its rollout gate.

After every filter in a group matches, the evaluator SHALL apply that group's `rollout_percentage`, defaulting an absent percentage to `100.0`. The first group whose filters match and whose rollout includes the effective bucketing identifier SHALL determine the flag value. The evaluator MUST NOT reorder groups to prioritize condition-level variant overrides.

For a matching multivariate condition, a condition-level `variant` SHALL be used only when it names one of the flag's defined variants. If the override is absent or invalid, the evaluator SHALL select a variant with the normal deterministic variant hash. A matching non-multivariate condition SHALL return `true`.

The flag-level `early_exit` selector SHALL default to `false`. When it is `true`, the evaluator SHALL return `false` immediately, with no variant or payload, only when every filter in the current group matched but that group's rollout excluded the effective bucketing identifier. A property, cohort, or dependency mismatch SHALL continue to the next group and SHALL NOT trigger `early_exit`. A locally inconclusive group SHALL also not itself trigger `early_exit`; the evaluator SHALL continue so another independently evaluable group can match, and SHALL preserve the existing inconclusive/remote-fallback outcome if no group produces a definitive result.

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

Each filter SHALL resolve against the context named by its filter type. Person and person-metadata filters SHALL use person context; group filters SHALL use the group context named by their own group type index, falling back to the condition's effective group aggregation when the filter has no index; cohort filters SHALL use person context; and flag-dependency filters SHALL use dependency evaluation results. A single condition MAY combine person and group filters, and all of them SHALL match before rollout is applied.

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

#### Scenario: One condition can AND person and group filters (@server)
- **GIVEN** a condition aggregates on group type "company"
- **AND** it requires person property "plan" equal to "pro"
- **AND** it requires company property "size" equal to "enterprise"
- **WHEN** the flag is evaluated locally for a pro person in an enterprise company
- **THEN** the condition should match
- **WHEN** either the person property or company property does not match
- **THEN** the condition should not match

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

Dependency filters SHALL be ANDed with every other filter in their condition. The evaluator SHALL resolve dependencies before selecting the dependent condition and MAY cache each dependency result for the current evaluation pass. A missing definition, unresolved dependency, or cycle SHALL make the dependent flag locally inconclusive and eligible for remote fallback; it SHALL NOT prevent independent flags in the same evaluation pass from being evaluated locally.

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

Because caller-supplied local property maps are partial context, an absent required property key SHALL make that criterion inconclusive for every ordinary property operator, including named negative operators. A value-requiring operator whose condition value is omitted SHALL be inconclusive. An operator that is unknown or invalid for the criterion type SHALL be inconclusive for only the affected flag.

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. A named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

#### Scenario: Operator omission defaults to exact (@server)
- **GIVEN** a local condition omits its property operator
- **AND** its condition value is `"PRO"`
- **WHEN** it is evaluated against supplied property value `"pro"`
- **THEN** it should match using `exact`

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

### Requirement: Exact and is_not compare scalar representations case-insensitively

The `exact` operator SHALL compare non-container JSON values after converting each to its compact scalar string representation and applying at least ASCII case-insensitive comparison. Strings SHALL retain their contents, booleans SHALL use lowercase `true`/`false`, numbers SHALL use a non-locale decimal representation, and JSON null SHALL use `null`. Consequently, string `"1"` SHALL equal numeric `1`, and string `"TRUE"` SHALL equal boolean `true`.

When the condition value is an array, `exact` SHALL match when any array member equals the supplied scalar property under the same comparison. A property-side array or object SHALL NOT be treated as an overlapping set. `is_not` SHALL be the logical complement of the valid `exact` comparison.

#### Scenario Outline: Exact and is_not use canonical coercion and condition-list membership (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `exact` | `"US"` | `"us"` | true |
  | `exact` | `1` | `"1"` | true |
  | `exact` | `true` | `"TRUE"` | true |
  | `exact` | `"null"` | null | true |
  | `exact` | `["US", "CA"]` | `"us"` | true |
  | `exact` | `["US", "CA"]` | `"gb"` | false |
  | `is_not` | `"US"` | `"us"` | false |
  | `is_not` | `["US", "CA"]` | `"gb"` | true |

### Requirement: String criteria use case-insensitive scalar-string comparisons

For `icontains`, `starts_with`, and `ends_with`, the evaluator SHALL convert the supplied property and condition value to their compact scalar string representations, apply at least ASCII case folding, and test whether the property contains, starts with, or ends with the condition value. Their `not_*` forms SHALL negate a valid comparison.

For `icontains_multi`, the condition value SHALL be an array and the criterion SHALL match when the supplied property contains at least one array member under the same case-insensitive scalar-string comparison. `not_icontains_multi` SHALL negate that valid any-member comparison. An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. A non-array multi-contains condition SHALL be malformed and therefore inconclusive.

#### Scenario Outline: String criteria compare the supplied property against the condition value (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `icontains` | `"EXAMPLE"` | `"Admin@example.com"` | true |
  | `not_icontains` | `"EXAMPLE"` | `"Admin@example.com"` | false |
  | `starts_with` | `"ADMIN@"` | `"admin@example.com"` | true |
  | `not_starts_with` | `"USER@"` | `"admin@example.com"` | true |
  | `ends_with` | `".COM"` | `"admin@example.com"` | true |
  | `not_ends_with` | `".ORG"` | `"admin@example.com"` | true |
  | `icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | true |
  | `not_icontains_multi` | `["enterprise", "PRO"]` | `"pro account"` | false |
  | `icontains_multi` | `[]` | `"pro account"` | false |
  | `not_icontains_multi` | `[]` | `"pro account"` | true |

### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition value SHALL be a regular-expression pattern and the compact scalar string representation of the supplied property SHALL be the input. Matching SHALL be case-sensitive unless the pattern itself enables case-insensitive behavior, and SHALL search the input rather than adding implicit start/end anchors. `not_regex` SHALL negate a valid search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. A runtime regex resource-limit failure SHALL be inconclusive for the affected flag. Regex compilation or execution MUST NOT throw into application code. Implementations MAY precompile patterns and use platform-appropriate backtracking, size, or execution limits.

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

### Requirement: Numeric criteria parse complete finite numbers and never compare lexicographically

For `gt`, `gte`, `lt`, and `lte`, the evaluator SHALL parse both operands as finite numbers and compare them in `property operator condition` order. JSON numbers and strings whose complete trimmed contents are valid numbers SHALL be accepted. Partial parses such as `"10px"`, non-finite values, null, arrays, and objects SHALL NOT be accepted as numbers. The evaluator MUST NOT fall back to lexicographic comparison.

The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`.

For dynamic-cohort property leaves, `between` SHALL accept exactly two finite numeric bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. `not_between` SHALL negate a valid inclusive range comparison. Missing, nonnumeric, non-finite, reversed, or malformed range operands SHALL NOT match either range operator; a malformed condition range SHALL be locally inconclusive.

#### Scenario Outline: Numeric ordering uses strict numeric semantics (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `gt` | `"9"` | `"10"` | true |
  | `gte` | `10` | `"10.0"` | true |
  | `lt` | `10` | `9` | true |
  | `lte` | `10` | `11` | false |
  | `min` | `10` | `10` | true |
  | `max` | `10` | `11` | false |
  | `gt` | `9` | `"10px"` | false |
  | `gt` | `9` | `"NaN"` | false |
  | `lt` | `9` | `"Infinity"` | false |

#### Scenario Outline: Dynamic-cohort ranges are inclusive and validate both bounds (@server)
- **GIVEN** a dynamic-cohort property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `between` | `[10, 20]` | `10` | true |
  | `between` | `[10, 20]` | `20` | true |
  | `between` | `[10, 20]` | `21` | false |
  | `not_between` | `[10, 20]` | `21` | true |
  | `not_between` | `[10, 20]` | `"not-a-number"` | false |
  | `not_between` | `[10, 20]` | `"NaN"` | false |
  | `between` | `[20, 10]` | `15` | inconclusive |
  | `not_between` | `[10]` | `15` | inconclusive |

### Requirement: Date criteria compare normalized instants

For `is_date_exact`, `is_date_after`, and `is_date_before`, the evaluator SHALL parse the supplied property and condition value as instants and compare them in `property operator condition` order. Exact SHALL require equal instants; before and after SHALL be strict.

An explicit `Z` or numeric offset SHALL be honored. A date-only or naive datetime SHALL use the project/team timezone when that timezone is available to the local evaluator and UTC otherwise. A supplied property MAY represent a Unix timestamp in seconds as a JSON number or complete numeric string.

A relative condition value SHALL consist of an optional leading `-`, an integer from `0` through `9999`, and one lowercase unit: `h`, `d`, `w`, `m`, or `y`. Both the unsigned and minus-prefixed forms SHALL select a lookback from the evaluator's current clock. Hours, days, and weeks SHALL subtract fixed durations; months and years SHALL use calendar-aware subtraction in the effective timezone, preserving the local time and clamping the day to the last valid day of the target month. Acceptance tests SHALL inject a fixed clock.

An invalid property date SHALL be a definitive no-match for every date operator. An invalid condition date SHALL make the criterion inconclusive. Boolean, array, and object values SHALL NOT be interpreted as dates.

#### Scenario Outline: Date criteria normalize offsets and preserve strict boundaries (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** a local property condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T12:00:00+02:00"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:01Z"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:00Z"` | false |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T09:59:59Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00"` | `"2025-01-01T10:00:00Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `1735725600` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"1735725600"` | true |
  | `is_date_after` | `"-7d"` | `"2025-01-02T00:00:00Z"` | true |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"not-a-date"` | false |
  | `is_date_before` | `"not-a-date"` | `"2025-01-01T10:00:00Z"` | inconclusive |

#### Scenario Outline: Relative date criteria use the canonical lookback grammar (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** a local property condition has operator `is_date_exact` and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | condition | property | matches |
  | `"-1h"` | `"2025-01-07T23:00:00Z"` | true |
  | `"1d"` | `"2025-01-07T00:00:00Z"` | true |
  | `"-1w"` | `"2025-01-01T00:00:00Z"` | true |
  | `"1m"` | `"2024-12-08T00:00:00Z"` | true |
  | `"-1y"` | `"2024-01-08T00:00:00Z"` | true |
  | `"10000d"` | `"2025-01-01T00:00:00Z"` | inconclusive |

### Requirement: Semantic-version criteria use canonical SemVer ordering and ranges

For `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, and `semver_lte`, the evaluator SHALL compare the supplied property version with the condition version using Semantic Versioning precedence.

Before parsing, the evaluator SHALL trim surrounding whitespace, remove one lowercase `v` prefix, pad an omitted minor or patch component with zero, and strip leading zeros from all-numeric core components. Prerelease identifiers SHALL participate in standard SemVer precedence. Build metadata SHALL be accepted but SHALL NOT affect equality or ordering.

`semver_tilde`, `semver_caret`, and `semver_wildcard` SHALL define lower-inclusive, upper-exclusive ranges. Tilde SHALL remain within the next minor boundary for a complete version. Caret SHALL remain within the next incompatible major/minor/patch boundary according to the first non-zero component. Wildcards SHALL admit the selected major or major/minor range.

An invalid property version SHALL be a definitive no-match for every semantic-version operator, including `semver_neq`. An invalid condition version or range SHALL make the criterion inconclusive.

#### Scenario Outline: Semantic-version comparison uses normalized SemVer precedence (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_eq` | `"1.2.0"` | `" v1.02 "` | true |
  | `semver_neq` | `"1.2.0"` | `"1.2.1"` | true |
  | `semver_gt` | `"1.2.3-beta.1"` | `"1.2.3"` | true |
  | `semver_gte` | `"1.2.3"` | `"1.2.3+build.7"` | true |
  | `semver_lt` | `"2.0.0"` | `"1.9.9"` | true |
  | `semver_lte` | `"1.2.3"` | `"1.2.4"` | false |
  | `semver_neq` | `"1.2.3"` | `"not-a-version"` | false |
  | `semver_eq` | `"not-a-version"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges are lower-inclusive and upper-exclusive (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_tilde` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.2.9"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.3.0"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_caret` | `"1.2.3"` | `"1.9.9"` | true |
  | `semver_caret` | `"1.2.3"` | `"2.0.0"` | false |
  | `semver_caret` | `"0.2.3"` | `"0.3.0"` | false |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.0"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.99"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.3.0"` | false |
  | `semver_tilde` | `"not-a-range"` | `"1.2.3"` | inconclusive |

### Requirement: Specialized cohort matching preserves scope, recursion, and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match when the referenced cohort membership or locally evaluable dynamic cohort expression matches; `not_in` SHALL negate a definitive membership result. A missing/static cohort definition, recursive cycle, unsupported cohort criterion, or required property unavailable from local context SHALL make the affected flag inconclusive and eligible for remote fallback.

Dynamic cohort property groups SHALL recursively apply their declared `AND` or `OR` composition. A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

#### Scenario Outline: Cohort membership operators compare the referenced membership (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort `42` has local membership result <membership>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion match result should be <matches>

  | operator | membership | matches |
  | omitted | true | true |
  | `in` | false | false |
  | `not_in` | true | false |
  | `not_in` | false | true |

#### Scenario: Negation does not turn an inconclusive cohort leaf into a match (@server)
- **GIVEN** a dynamic cohort contains a negated leaf whose required person property is unavailable locally
- **WHEN** a feature flag depending on that cohort is evaluated locally
- **THEN** the cohort criterion should be inconclusive
- **AND** the negation should not turn it into a match
- **AND** remote evaluation should remain eligible
