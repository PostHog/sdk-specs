# Is Feature Enabled Specification

## Purpose

`is-feature-enabled` answers the boolean question: **should this feature be treated as enabled for this user/context right now?**

It is the boolean-oriented counterpart to `get-feature-flag`:

- `get-feature-flag` returns the raw matched value (`true`, `false`, or a variant string)
- `is-feature-enabled` converts that result into on/off semantics

In most SDKs, a multivariate string result is treated as **enabled**.

## Applicability

`both` — client and server SDKs both expose a boolean feature-flag check, but they evaluate from different sources.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached group/person context. | Caller passes `distinct_id` explicitly per call. |
| Data source | Reads from locally cached feature flags previously loaded by initialization / `reloadFeatureFlags()`. | Evaluates locally and/or remotely on demand for the provided user context. |
| Network I/O | Usually none at read time. | May perform remote evaluation depending on SDK/configuration. |
| Unknown flag behavior | Varies between `undefined` and `false` when flags are missing/unloaded. | Varies between `undefined` / `None` and `false`, depending on SDK. |
| Tracking side effect | Often emits `$feature_flag_called` by default. | Often emits `$feature_flag_called` by default. |

## Public signatures

### Client-side canonical signature

```ts
isFeatureEnabled(
  key: string,
  options?: {
    sendFeatureFlagEvent?: boolean,
  },
): boolean | undefined
```

### Server-side canonical signature

```ts
isFeatureEnabled(
  key: string,
  distinct_id: string,
  options?: {
    groups?: Record<string, string>,
    personProperties?: Record<string, unknown>,
    groupProperties?: Record<string, Record<string, unknown>>,
    onlyEvaluateLocally?: boolean,
    sendFeatureFlagEvents?: boolean,
    disableGeoip?: boolean,
    deviceId?: string,
    defaultValue?: boolean,
  },
): Promise<boolean | undefined> | boolean | undefined
```

### Surface variants

- **posthog-js core / browser / react-native:** `isFeatureEnabled(key)`
- **flutter:** `isFeatureEnabled(key): Future<bool>`
- **iOS:** `isFeatureEnabled(_ key: String)` and `isFeatureEnabled(_ key: String, sendFeatureFlagEvent: Bool)`
- **Android:** `isFeatureEnabled(key, defaultValue = false, sendFeatureFlagEvent = null)`
- **Unity:** `IsFeatureEnabled(key, defaultValue = false)`
- **Node:** `await isFeatureEnabled(key, distinctId, options?)`
- **Python:** `feature_enabled(key, distinct_id, ..., send_feature_flag_events=True, ...)`
- **Ruby:** `is_feature_enabled(key, distinct_id, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false, send_feature_flag_events: true)`
- **PHP:** `isFeatureEnabled(key, distinctId, groups = [], personProperties = [], groupProperties = [], onlyEvaluateLocally = false, sendFeatureFlagEvents = true)`
- **.NET:** `await IsFeatureEnabledAsync(featureKey, distinctId, options?)`

## Behavior

### Client-side flow

1. **Look up the current feature-flag value** from the SDK's local flag cache.
2. **Convert the raw flag value to boolean semantics:**
   - `true` stays `true`
   - `false` stays `false`
   - a non-empty variant string is treated as `true`
   - if the flag is unavailable, SDKs vary between returning `undefined` and falling back to `false` / a supplied default
3. **Optionally emit `$feature_flag_called`.** In audited client SDKs this is usually enabled by default and can be disabled per call in some implementations.
4. **Do not fetch from the network directly.** The method uses the currently cached flags; callers wanting fresh values must reload flags separately.

### Server-side flow

1. **Resolve evaluation context** from the provided `distinct_id` plus any optional groups, person properties, group properties, device id, and geoip settings.
2. **Evaluate the flag** locally and/or remotely according to the SDK's feature-flag engine and configuration.
3. **Convert the result to boolean semantics:**
   - boolean-enabled → `true`
   - boolean-disabled → `false`
   - variant string → `true`
   - unavailable / unknown → `undefined` / `None` in some SDKs, or `false` / default in others
4. **Optionally emit `$feature_flag_called`.** Server SDKs commonly track accesses by default.

## State & lifecycle

### Client-side state

- Reads from the feature-flag cache maintained by initialization and `reloadFeatureFlags()`.
- May mutate per-flag dedupe bookkeeping used to suppress duplicate `$feature_flag_called` events.
- Does not normally mutate identity or other ambient state.

### Server-side state

- Reads per-call evaluation inputs.
- May read local flag-definition caches / stale per-user result caches.
- May update caches or dedupe maps associated with feature-flag-called tracking.

## Error handling

- Client SDKs should not throw in normal operation.
- Server SDKs usually absorb evaluation/network failures and return `undefined`, `false`, or a stale fallback rather than crashing application code.
- `$feature_flag_called` tracking failures should not affect the boolean result.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned result reflects the cached flags available at the time of the call.
- If a reload is racing, callers may observe either the old or the newly-refreshed value.
- Server evaluations are per-call and independent, except where shared local caches or dedupe maps are used.

## Interactions

- **`get-feature-flag`** — this is usually a boolean wrapper around the raw flag value returned there.
- **`get-feature-flag-payload`** — often used after a positive `is-feature-enabled` result to fetch variant payload.
- **`reload-feature-flags`** — refreshes the client-side cache this method reads.
- **`$feature_flag_called`** — many SDKs emit this analytics event when the method is called.
- **`identify` / `group` / flag-property setters** — change the evaluation context for subsequent calls.

## Requirements

### Requirement: Canonical is-feature-enabled behavior

The SDK SHALL implement the canonical `is-feature-enabled` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Enabled check maps flag values to booleans (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value        |
  | feature | <flag_value> |
- **WHEN** is feature enabled "feature" is called
- **THEN** the returned enabled value should be <enabled>
  Examples:
  | flag_value | enabled |
  | true       | true    |
  | false      | false   |
  | variant-a  | true    |

#### Scenario: Enabled check returns false for missing flags (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are empty
- **WHEN** is feature enabled "missing" is called
- **THEN** the returned enabled value should be false

#### Scenario: Enabled check can suppress tracking (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | feature | true  |
- **WHEN** is feature enabled "feature" is called with tracking disabled
- **THEN** the returned enabled value should be true
- **AND** no event named "$feature_flag_called" should be enqueued
