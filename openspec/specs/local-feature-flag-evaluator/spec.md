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
