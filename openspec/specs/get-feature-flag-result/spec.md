# Get Feature Flag Result Specification

## Purpose

`get-feature-flag-result` returns a **structured result object** for a feature flag evaluation instead of only the raw value or payload.

It is the combined form of the feature-flag APIs and typically includes:

- the flag key
- whether the flag is enabled
- the matched variant, if any
- the payload, if any
- in some SDKs, additional metadata such as an evaluation reason

This is the preferred API when callers need more than a boolean or variant string and want to avoid making separate `get-feature-flag` and `get-feature-flag-payload` calls.

## Applicability

`both` — client and server SDKs expose structured flag results, but they derive them differently.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached flag state. | Caller passes `distinct_id` explicitly per call. |
| Data source | Reads from the locally cached feature-flag response. | Evaluates locally and/or remotely on demand for the provided context. |
| Network I/O | Usually none at read time. | May do local evaluation only, remote evaluation, or both. |
| Tracking side effect | Often sends `$feature_flag_called` by default unless suppressed. | Often sends `$feature_flag_called` by default unless suppressed. |
| Return object shape | Usually `{ key, enabled, variant, payload }`. | Usually the same core fields, with some SDKs adding extra metadata such as a reason. |

## Public signatures

### Client-side canonical signature

```ts
getFeatureFlagResult(
  key: string,
  options?: {
    sendFeatureFlagEvent?: boolean,
  },
): {
  key: string
  enabled: boolean
  variant?: string
  payload?: unknown
} | undefined
```

### Server-side canonical signature

```ts
getFeatureFlagResult(
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
  },
): Promise<FeatureFlagResult | undefined> | FeatureFlagResult | undefined
```

Where the canonical result object is:

```ts
type FeatureFlagResult = {
  key: string
  enabled: boolean
  variant?: string
  payload?: unknown
}
```

### Surface variants

- **posthog-js core / browser / react-native:** `getFeatureFlagResult(key, options?)`
- **flutter:** `getFeatureFlagResult(key, { sendEvent = true }): Future<PostHogFeatureFlagResult?>`
- **Node:** `await getFeatureFlagResult(key, distinctId, options?)`
- **Python:** `get_feature_flag_result(key, distinct_id, *, ...)`
- **Ruby:** `get_feature_flag_result(key, distinct_id, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false, send_feature_flag_events: true)`
- **PHP:** `getFeatureFlagResult(key, distinctId, groups = [], personProperties = [], groupProperties = [], onlyEvaluateLocally = false, sendFeatureFlagEvents = true)`
- **iOS:** `getFeatureFlagResult(_ key: String)` and `getFeatureFlagResult(_ key: String, sendFeatureFlagEvent: Bool)`
- **Android:** `getFeatureFlagResult(key, sendFeatureFlagEvent = null)`
- **.NET:** `await GetFeatureFlagAsync(featureKey, distinctId, options?)` returning a `FeatureFlag?` record/object with equivalent fields

## Behavior

### Client-side flow

1. **Read the cached flag entry** from the SDK's local feature-flag cache.
2. **Assemble the result object** from the cached value and payload.
   - Boolean flag → `enabled = true|false`, `variant = undefined`
   - Multivariate flag → `enabled = true`, `variant = '<variant>'`
   - Payload is attached if available.
3. **Handle missing/unknown flags.** If the SDK cannot determine the flag from cache, return `undefined` / `nil` rather than a partial result object.
4. **Optionally emit `$feature_flag_called`.** In audited client SDKs this is on by default and can be suppressed with a per-call option in some implementations.
5. **Do not fetch from the network directly.** The method uses currently cached flag state; callers wanting fresh data must reload flags separately.

### Server-side flow

1. **Resolve evaluation context** from `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Evaluate the flag** locally and/or remotely according to SDK configuration.
3. **Construct the result object** from the resolved value and payload.
   - Boolean flag → `enabled = true|false`, `variant = undefined`
   - Multivariate flag → `enabled = true`, `variant = '<variant>'`
   - Attach payload when available
4. **Return `undefined` / `None` when no result is available.** This usually covers unknown flags, unavailable caches, or evaluation failure with no fallback.
5. **Optionally emit `$feature_flag_called`.** Server SDKs commonly track accesses by default.

## State & lifecycle

### Client-side state

- Reads from the cached feature-flag store maintained by initialization and `reloadFeatureFlags()`.
- May mutate dedupe bookkeeping for `$feature_flag_called` tracking.
- Does not normally mutate identity or other ambient state.

### Server-side state

- Reads per-call evaluation inputs.
- May read local flag-definition caches / stale per-user result caches.
- May update caches or dedupe maps associated with feature-flag-called tracking.

## Error handling

- Client SDKs should not throw in normal operation.
- Server SDKs usually absorb evaluation/network failures and return `undefined`, `None`, or stale fallback-derived results rather than crashing application code.
- Payload parsing or metadata extraction failures should not crash the caller; SDKs either log and continue or omit the problematic data.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned object reflects the flag cache available at the instant of the call.
- If a reload is racing, callers may observe either the old or newly-refreshed result.
- Server evaluations are per-call and independent, except where shared caches or dedupe maps are used.

## Interactions

- **`get-feature-flag`** — can be derived from this result object's `variant ?? enabled`.
- **`is-feature-enabled`** — can be derived from this result object's `enabled` field.
- **`get-feature-flag-payload`** — can be derived from this result object's `payload` field.
- **`reload-feature-flags`** — refreshes the client-side cache this method reads.
- **`$feature_flag_called`** — often emitted by this method unless explicitly suppressed.

## Requirements

### Requirement: Canonical get-feature-flag-result behavior

The SDK SHALL implement the canonical `get-feature-flag-result` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Structured result includes key enabled variant and payload (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value | payload              |
  | checkout | blue  | {"copy":"new"}    |
- **WHEN** get feature flag result "checkout" is called
- **THEN** the returned feature flag result should include:
  | field   | value           |
  | key     | checkout        |
  | enabled | true            |
  | variant | blue            |
  | payload | {"copy":"new"} |

#### Scenario: Boolean false flag result is disabled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | false |
- **WHEN** get feature flag result "beta-ui" is called
- **THEN** the returned feature flag result should include:
  | field   | value   |
  | key     | beta-ui |
  | enabled | false   |
- **AND** the returned feature flag result should not include a variant

#### Scenario: Unknown flag returns no structured result (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are empty
- **WHEN** get feature flag result "missing-flag" is called
- **THEN** no feature flag result should be returned
