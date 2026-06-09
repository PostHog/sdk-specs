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
6. **Match flag conditions locally.** Evaluate property filters, rollout percentages, multivariate overrides, and dependency chains using local definitions.
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
