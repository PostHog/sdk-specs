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

The local evaluator's property-filter matching SHALL support the `starts_with`,
`not_starts_with`, `ends_with`, and `not_ends_with` operators. Matching SHALL stringify both the
property value and the filter value, lowercase them using ASCII case-folding, and compare with a
prefix check (`starts_with`/`not_starts_with`) or suffix check (`ends_with`/`not_ends_with`),
negating the result for the `not_*` variants — the same case-insensitive, stringify-first
approach already used for `icontains`. These operators mirror the corresponding server-side
flags-service operators so that locally-evaluated results agree with remote evaluation.

When the property required for evaluation is absent from the supplied context, matching SHALL be
inconclusive (deferring to remote evaluation), consistent with how other operators handle a
missing property.

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
