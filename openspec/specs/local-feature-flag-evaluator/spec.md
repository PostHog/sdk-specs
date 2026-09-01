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
6. **Match flag conditions locally.** Evaluate property filters, rollout percentages, multivariate overrides, and dependency chains using local definitions. See the backend-compatible stringification, exact equality, and ASCII string-search requirements below for property-filter matching.
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

### Requirement: Multi-contains string search uses ANY semantics

The local evaluator SHALL implement `icontains_multi` and `not_icontains_multi` with an array condition. It SHALL stringify the supplied property and each condition member with the backend-compatible representation, lowercase only ASCII characters `A` through `Z`, and compare each member as a substring. `icontains_multi` SHALL match when ANY member matches. `not_icontains_multi` SHALL be the logical inverse for a present, supported property value.

An empty condition array SHALL make `icontains_multi` false and `not_icontains_multi` true. When the required property key is absent from caller-supplied local evaluation context, both operators SHALL remain inconclusive and eligible for remote fallback.

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

Because caller-supplied local property maps are partial context, an absent required property key SHALL make that criterion inconclusive for every ordinary property operator, including named negative operators. A value-requiring operator whose condition value is omitted SHALL be inconclusive. An operator that is unknown or invalid for the criterion type SHALL be inconclusive for only the affected flag.

When both operands are available but the property value cannot be interpreted by the selected operator, the criterion SHALL be a definitive no-match. A malformed condition value SHALL be inconclusive unless an operator-family requirement explicitly defines a safe result. A named negative operator SHALL negate only a valid comparison; it MUST NOT convert an invalid pattern, invalid numeric/date/version operand, or inconclusive criterion into a match. Implementations MUST NOT expose parser or matcher exceptions to application code.

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
  | `exact` | omitted | property value `"pro"` present | inconclusive |
  | `future_operator` | `"pro"` | property value `"pro"` present | inconclusive |
  | `gt` | `"10"` | property value `"not-a-number"` present | false |
  | `gt` | `"not-a-number"` | property value `10` present | inconclusive |

### Requirement: Regular-expression criteria perform safe case-sensitive search

For `regex` and `not_regex`, the condition SHALL be a string pattern. The evaluator SHALL stringify the supplied property using the compact JSON rules defined for equality. Matching SHALL be case-sensitive unless the pattern enables case-insensitive behavior, and SHALL search the input without adding implicit anchors. An empty pattern therefore matches every present property value. `not_regex` SHALL negate only a successfully compiled and executed search result.

A syntactically invalid pattern SHALL produce a definitive no-match for both `regex` and `not_regex`. Syntax unsupported by an SDK's regex engine, or a regex execution failure, SHALL be inconclusive for that flag and MUST NOT become a match through `not_regex` or cohort negation. Regex matching MUST NOT throw into application code.

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

#### Scenario: Unsupported regex execution is inconclusive (@server)
- **GIVEN** a pattern uses syntax unsupported by the SDK regex engine
- **WHEN** the pattern is evaluated with `regex` or `not_regex`
- **THEN** local evaluation should be inconclusive for that flag
- **AND** neither a negative operator nor cohort negation should turn the failure into a match

### Requirement: Numeric criteria use complete finite binary64 comparisons

For `gt`, `gte`, `lt`, and `lte`, the condition SHALL be a string matching the complete decimal grammar `[+-]?(digits[.digits*]?|.digits+)([eE][+-]?digits+)?`, where `digits` means one or more ASCII decimal digits and `digits*` means zero or more. The supplied property MAY be a JSON number or a string matching the same grammar. The evaluator SHALL convert both operands to finite IEEE-754 binary64 values and compare them in `property operator condition` order. No whitespace is trimmed. Partial parses such as `"10px"`, padded strings such as `" 10 "`, non-finite values, null, booleans, arrays, and objects SHALL NOT be accepted. The evaluator MUST NOT fall back to lexicographic or arbitrary-precision decimal comparison.

The legacy wire alias `min` SHALL behave as `gte`, and `max` SHALL behave as `lte`.

A present property that cannot be converted to a finite number SHALL be a definitive no-match. An invalid condition number SHALL be inconclusive. Binary64 rounding is observable for values that cannot be represented exactly.

For dynamic-cohort property leaves, `between` SHALL accept exactly two finite numeric or numeric-string bounds `[low, high]`, require `low <= high`, and match inclusively at both bounds. `not_between` SHALL negate only a valid inclusive range comparison. Missing, nonnumeric, non-finite, reversed, or malformed ranges SHALL NOT match either range operator; a malformed condition range SHALL be inconclusive before applying any cohort leaf `negation`.

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
  | `not_between` | `[10, 20]` | `"not-a-number"` | false |
  | `not_between` | `[10, 20]` | `"NaN"` | false |
  | `between` | `[10, 20]` | `"inf"` | false |
  | `not_between` | `[10, 20]` | `"inf"` | false |
  | `between` | `[20, 10]` | `15` | inconclusive |
  | `not_between` | `[10]` | `15` | inconclusive |
  | `between` | `["-inf", "inf"]` | `0` | inconclusive |

#### Scenario: Cohort negation does not invert a malformed range (@server)
- **GIVEN** a dynamic cohort leaf has condition `between [1,2,3]`
- **AND** the leaf sets `negation` to true
- **WHEN** it is evaluated against property `2`
- **THEN** the cohort leaf should be inconclusive
- **AND** negation should not turn it into a match

### Requirement: Date criteria compare normalized instants in the effective timezone

For `is_date_exact`, `is_date_after`, and `is_date_before`, the evaluator SHALL parse the supplied property and condition as instants and compare them in `property operator condition` order. Exact SHALL require equal instants; before and after SHALL be strict.

The portable absolute-date grammar SHALL include RFC 3339 values with `Z` or a numeric offset, `YYYY-MM-DD`, and naive `YYYY-MM-DD[ T]HH:MM[:SS[.fraction]]`. Explicit offsets SHALL be honored. Date-only and naive values SHALL use the project/team timezone when available to the evaluator and UTC otherwise. An implementation accepting an additional naive format SHALL interpret it in the effective timezone rather than silently using UTC.

A property MAY represent integral Unix seconds as a finite JSON integer or complete unpadded integer string. Fractional and non-finite values, booleans, arrays, and objects are outside this contract and SHALL NOT be interpreted as dates.

A relative condition SHALL consist of an optional leading `-`, an integer from `0` through `9999`, and one lowercase unit: `h`, `d`, `w`, `m`, or `y`. Both unsigned and minus-prefixed forms select a lookback. The evaluator SHALL convert its current instant to the effective timezone, subtract on the naive local wall clock, and convert the result back to an instant. Hours, days, and weeks therefore preserve wall-clock subtraction across offset changes rather than guaranteeing a fixed elapsed duration.

On a fall-back overlap, the evaluator SHALL choose the earlier of the two matching instants. If subtraction or naive parsing lands in a spring-forward gap, the criterion SHALL be inconclusive. Month and year lookbacks SHALL subtract one unit at a time, preserving the current local time and clamping after every step. Consequently, a two-month lookback from March 31 can retain February's clamped day in January. Acceptance tests SHALL inject both a fixed clock and an effective timezone.

A present property that is outside the accepted grammar SHALL be a definitive no-match. An omitted, non-string, invalid, or locally uninterpretable condition SHALL be inconclusive.

#### Scenario Outline: Date criteria normalize offsets and preserve strict boundaries (@server)
- **GIVEN** the local evaluator clock is fixed at `2025-01-08T00:00:00Z`
- **AND** the effective timezone is `UTC`
- **AND** a local property condition has operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T12:00:00+02:00"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:01Z"` | true |
  | `is_date_after` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T10:00:00Z"` | false |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"2025-01-01T09:59:59Z"` | true |
  | `is_date_exact` | `"2025-01-01T10:00"` | `"2025-01-01 10:00:00"` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `1735725600` | true |
  | `is_date_exact` | `"2025-01-01T10:00:00Z"` | `"1735725600"` | true |
  | `is_date_before` | `"2025-01-01T10:00:00Z"` | `"not-a-date"` | false |
  | `is_date_before` | `"not-a-date"` | `"2025-01-01T10:00:00Z"` | inconclusive |

#### Scenario: Naive dates use the team timezone (@server)
- **GIVEN** the effective timezone is `America/Los_Angeles`
- **AND** an `is_date_after` condition has value `"2024-06-01"`
- **WHEN** it is evaluated against property `"2024-06-01T03:00:00Z"`
- **THEN** the criterion should not match

#### Scenario Outline: Relative dates use local wall-clock lookbacks (@server)
- **GIVEN** the effective timezone is `UTC`
- **AND** the local evaluator clock is fixed at <clock>
- **AND** an `is_date_exact` condition has value <condition>
- **WHEN** it is evaluated against property <property>
- **THEN** the criterion result should be <result>

  | clock | condition | property | result |
  | `2025-01-08T00:00:00Z` | `"-1h"` | `"2025-01-07T23:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"1d"` | `"2025-01-07T00:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"-1w"` | `"2025-01-01T00:00:00Z"` | true |
  | `2025-03-31T12:00:00Z` | `"2m"` | `"2025-01-28T12:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"-1y"` | `"2024-01-08T00:00:00Z"` | true |
  | `2025-01-08T00:00:00Z` | `"10000d"` | `"2025-01-01T00:00:00Z"` | inconclusive |

#### Scenario Outline: Relative dates define DST overlap and gap behavior (@server)
- **GIVEN** the effective timezone is `America/Los_Angeles`
- **AND** the local evaluator clock is fixed at <clock>
- **AND** an `is_date_exact` condition has value <condition>
- **WHEN** it is evaluated against property <property>
- **THEN** the criterion result should be <result>

  | clock | condition | property | result |
  | `2024-11-03T10:30:00Z` | `"1h"` | `"2024-11-03T08:30:00Z"` | true |
  | `2024-03-10T10:30:00Z` | `"1h"` | `"2024-03-10T09:30:00Z"` | inconclusive |

### Requirement: Semantic-version criteria use consistent normalization and range matching

For direct `semver_eq`, `semver_neq`, `semver_gt`, `semver_gte`, `semver_lt`, and `semver_lte`, the evaluator SHALL stringify each JSON operand, remove one lowercase `v` prefix only when it is the first character, then trim surrounding whitespace. It SHALL pad an omitted minor or patch component with zero and strip leading zeros from all-numeric core components before parsing. Thus `v1.02`, `v 1.02`, and ` 1.02 ` normalize to `1.2.0`, while ` v1.02 ` is invalid because prefix removal occurs before trimming. JSON numeric properties such as `1` and `1.2` are runtime-compatible and normalize to `1.0.0` and `1.2.0`.

Core components SHALL be unsigned 64-bit integers. More than three core components, an empty prerelease suffix such as `1.2.3-`, and other invalid SemVer syntax SHALL be rejected. Prerelease identifiers SHALL use standard SemVer precedence. Direct equality SHALL distinguish versions whose build metadata differs. Direct ordering SHALL compare dot-separated build identifiers lexicographically, comparing numeric identifiers numerically and sorting them before nonnumeric identifiers. Range matching SHALL ignore build metadata.

For `semver_tilde` and `semver_caret`, the evaluator SHALL normalize and pad the condition to a complete version before applying the corresponding range. Consequently `~1` behaves as `~1.0.0`, and `^0` behaves as `^0.0.0`. For `semver_wildcard`, it SHALL strip leading zeros from numeric components without padding and accept `*`, `x`, or `X` as wildcard tokens. Supported spellings include `*`, `x`, `X`, `1.*`, `1.*.*`, and `1.2.*`; an interior wildcard such as `1.*.3` is invalid. A condition without a wildcard token, such as `1.2`, uses caret semantics.

A prerelease property SHALL satisfy a range only when the range contains a prerelease comparator with the same major, minor, and patch tuple. An invalid property version SHALL be a definitive no-match for every semantic-version operator, including `semver_neq`; an omitted or invalid condition version or range SHALL be inconclusive.

#### Scenario Outline: Direct semantic-version comparison uses normalized total ordering (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `semver_eq` | `"1.2.0"` | `"v1.02"` | true |
  | `semver_eq` | `"1.2.0"` | `"v 1.02"` | true |
  | `semver_eq` | `"1.2.0"` | `" v1.02 "` | false |
  | `semver_eq` | `"1.2.0"` | `1.2` | true |
  | `semver_neq` | `"1.2.0"` | `"1.2.1"` | true |
  | `semver_gt` | `"1.2.3-beta.1"` | `"1.2.3"` | true |
  | `semver_gte` | `"1.2.3"` | `"1.2.3"` | true |
  | `semver_eq` | `"1.2.3"` | `"1.2.3+build.7"` | false |
  | `semver_gt` | `"1.2.3+build.1"` | `"1.2.3+build.2"` | true |
  | `semver_lt` | `"2.0.0"` | `"1.9.9"` | true |
  | `semver_lte` | `"1.2.3"` | `"1.2.4"` | false |
  | `semver_neq` | `"1.2.3"` | `"not-a-version"` | false |
  | `semver_eq` | `"1.2.3"` | `"1.2.3.4"` | false |
  | `semver_eq` | `"1.2.3-"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges use consistent boundaries (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion result should be <result>

  | operator | condition | property | result |
  | `semver_tilde` | `"1.2.3"` | `"1.2.9"` | true |
  | `semver_tilde` | `"1.2.3"` | `"1.3.0"` | false |
  | `semver_tilde` | `"1"` | `"1.1.0"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.9.9"` | true |
  | `semver_caret` | `"1.2.3"` | `"2.0.0"` | false |
  | `semver_caret` | `"0.2.3"` | `"0.3.0"` | false |
  | `semver_caret` | `"0"` | `"0.0.1"` | false |
  | `semver_caret` | `"0.0.0"` | `"0.0.1"` | false |
  | `semver_tilde` | `"1.2.0"` | `1.2` | true |
  | `semver_tilde` | `"1.2.3+build.7"` | `"1.2.4+other"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.99"` | true |
  | `semver_wildcard` | `"1.2.*"` | `"1.3.0"` | false |
  | `semver_wildcard` | `"1.*.*"` | `"1.9.0"` | true |
  | `semver_wildcard` | `"1.2"` | `"1.9.0"` | true |
  | `semver_wildcard` | `"1.*.3"` | `"1.2.3"` | inconclusive |
  | `semver_tilde` | `"not-a-range"` | `"1.2.3"` | inconclusive |

#### Scenario Outline: Semantic-version ranges apply prerelease admission (@server)
- **GIVEN** a local property condition with operator <operator> and condition value <condition>
- **WHEN** it is evaluated against supplied property value <property>
- **THEN** the criterion match result should be <matches>

  | operator | condition | property | matches |
  | `semver_tilde` | `"1.2.3"` | `"1.2.4-beta.1"` | false |
  | `semver_caret` | `"1.2.3"` | `"1.3.0-beta.1"` | false |
  | `semver_wildcard` | `"1.2.*"` | `"1.2.4-beta.1"` | false |
  | `semver_tilde` | `"1.2.3-beta.1"` | `"1.2.3-beta.2"` | true |
  | `semver_tilde` | `"1.2.3-beta.1"` | `"1.2.4-beta.1"` | false |

### Requirement: Specialized cohort matching preserves scope and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match a definitive referenced membership result; `not_in` SHALL negate only a definitive result. A static cohort with cached local membership is therefore conclusive. A static cohort definition without membership data, a missing dynamic definition, a dependency cycle, or unavailable required context SHALL be inconclusive and MUST NOT be represented as membership false merely to evaluate `not_in`.

Dynamic cohort groups SHALL recursively apply three-valued composition. `OR` returns true when any child is true, false when every child is false, and inconclusive otherwise. `AND` and its legacy wire alias `property` return false when any child is false, true when every child is true, and inconclusive otherwise. An empty `OR` is false; an empty `AND` or `property` group is true.

A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. Unsupported or malformed cohort criteria SHALL be inconclusive and MUST NOT throw into application code. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

Implementations SHALL detect cohort cycles and bound recursion. A definition beyond an implementation's safe recursion bound MAY become inconclusive, but MUST NOT be silently truncated or crash application code.

#### Scenario Outline: Cohort membership operators compare definitive membership (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort `42` has a definitive local membership result <membership>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion match result should be <matches>

  | operator | membership | matches |
  | omitted | true | true |
  | `in` | false | false |
  | `not_in` | true | false |
  | `not_in` | false | true |

#### Scenario Outline: Unavailable membership remains inconclusive for both polarities (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort membership is unavailable because <reason>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion should be inconclusive
- **AND** remote evaluation should remain eligible

  | operator | reason |
  | `in` | the static cohort has no cached membership |
  | `not_in` | the static cohort has no cached membership |
  | `not_in` | the dynamic cohort definition is missing |
  | `not_in` | the cohort dependency graph contains a cycle |

#### Scenario Outline: Dynamic cohort groups use three-valued composition (@server)
- **GIVEN** a dynamic cohort group combines child results <children> with group type <group-type>
- **WHEN** the group is evaluated locally
- **THEN** the group result should be <result>

  | group-type | children | result |
  | `OR` | true and inconclusive | true |
  | `OR` | false and inconclusive | inconclusive |
  | `AND` | false and inconclusive | false |
  | `AND` | true and inconclusive | inconclusive |
  | `property` | true and true | true |
  | `OR` | no children | false |
  | `AND` | no children | true |

#### Scenario: Negation does not turn an inconclusive cohort leaf into a match (@server)
- **GIVEN** a dynamic cohort contains a negated leaf whose required person property is unavailable locally
- **WHEN** a feature flag depending on that cohort is evaluated locally
- **THEN** the cohort criterion should be inconclusive
- **AND** the negation should not turn it into a match
- **AND** remote evaluation should remain eligible

#### Scenario Outline: Malformed cohort structures are inconclusive (@server)
- **GIVEN** a referenced dynamic cohort contains <malformation>
- **AND** the outer membership operator is `not_in`
- **WHEN** the cohort condition is evaluated locally
- **THEN** the cohort condition should be inconclusive
- **AND** `not_in` should not turn the failure into a match

  | malformation |
  | a known leaf type missing its required key |
  | unknown group type `XOR` |
