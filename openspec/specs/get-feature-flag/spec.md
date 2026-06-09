# Get Feature Flag Specification

## Purpose

`get-feature-flag` returns the current value of a feature flag for a user.

The returned value is the **flag's actual match value**:

- `true` for a boolean-enabled flag
- `false` for a boolean-disabled flag in SDKs that treat the flag as known-but-disabled
- a `string` variant key for multivariate flags
- `undefined` / `null` when the SDK cannot determine a value or considers the flag unavailable

This API is often paired with `get-feature-flag-payload` and `is-feature-enabled`:

- `get-feature-flag` answers “what value matched?”
- `is-feature-enabled` answers “should I treat this as on?”
- `get-feature-flag-payload` returns the payload associated with the matched value

## Applicability

`both` — client and server SDKs both expose a feature-flag lookup API, but with very different data sources.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached group/person context. | Caller passes `distinct_id` explicitly per call. |
| Data source | Reads from the locally-cached flag state previously loaded by `reloadFeatureFlags()` / initialization. | Evaluates locally and/or remotely on demand for the provided user context. |
| Network I/O | Usually **no** network call at read time; cache must already be populated. | May do local evaluation only, remote evaluation, or both, depending on SDK/configuration. |
| Missing flag behavior | Often returns `undefined` before flags are loaded, then `false` for known missing flags once cache exists. | Commonly returns `false` for disabled, variant string for multivariate, and `undefined` / `None` when unavailable or unknown. |
| Tracking side effect | Often sends `$feature_flag_called` by default, with SDK-specific deduping. | Often sends `$feature_flag_called` by default as part of evaluation. |

## Public signatures

### Client-side canonical signature

```ts
getFeatureFlag(
  key: string,
  options?: {
    sendFeatureFlagEvent?: boolean,
  },
): boolean | string | undefined
```

### Server-side canonical signature

```ts
getFeatureFlag(
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
): Promise<boolean | string | undefined> | boolean | string | undefined
```

### Surface variants

- **posthog-js core / browser / react-native:** `getFeatureFlag(key)`
- **flutter:** `getFeatureFlag(key): Future<Object?>`
- **iOS:** `getFeatureFlag(_ key: String)` and `getFeatureFlag(_ key: String, sendFeatureFlagEvent: Bool)`
- **Android:** `getFeatureFlag(key, defaultValue = null, sendFeatureFlagEvent = null)`
- **Node:** `await getFeatureFlag(key, distinctId, options?)`
- **Python:** `get_feature_flag(key, distinct_id, *, groups=None, person_properties=None, group_properties=None, only_evaluate_locally=False, send_feature_flag_events=True, disable_geoip=None, device_id=None)`
- **Ruby:** `get_feature_flag(key, distinct_id, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false, send_feature_flag_events: true)`
- **PHP:** `getFeatureFlag(key, distinctId, groups = [], personProperties = [], groupProperties = [], onlyEvaluateLocally = false, sendFeatureFlagEvents = true)`

## Behavior

### Client-side flow

1. **Read cached flag state.** Look up the current flag from the SDK's locally stored feature-flag details/cache.
2. **Compute the return value.**
   - If the cached flag value is a variant string, return that string.
   - If the cached flag value is a boolean, return that boolean.
   - If the flag is missing, SDKs vary between returning `undefined` and returning `false` once a non-empty flags response is known.
3. **Optionally send `$feature_flag_called`.** In audited client SDKs this is on by default and can be disabled with a per-call option in some SDKs. Calls are often deduplicated per flag/value pair to avoid repeated tracking spam.
4. **Do not fetch from the network directly.** The method uses whatever flags are already cached; callers wanting fresh values must use `reloadFeatureFlags()`.

### Server-side flow

1. **Resolve evaluation context.** Use the caller-provided `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Evaluate the flag.**
   - If local evaluation is enabled and the flag can be computed locally, return the local result.
   - Otherwise, fall back to a remote flags/decide request when supported.
   - Some SDKs use stale cache fallbacks on remote failures.
3. **Compute the return value.**
   - Disabled known flag → `false`
   - Multivariate match → variant string
   - Unknown / unavailable / not yet determinable → `undefined` / `None`
4. **Optionally send `$feature_flag_called`.** Server SDKs commonly track flag usage by default and allow opting out per call.

## State & lifecycle

### Client-side state

- Reads from the feature-flag cache maintained by initialization and `reloadFeatureFlags()`.
- Reads ambient identity, groups, and local flag-related caches indirectly through that stored state.
- Does not normally mutate core identity state.
- May mutate local “flag call reported” bookkeeping used to dedupe `$feature_flag_called` events.

### Server-side state

- Reads per-call evaluation inputs.
- May read local flag-definition caches / pollers / stale per-user result caches.
- May update per-user dedupe caches for `$feature_flag_called` events and local feature-flag caches.

## Error handling

- Client SDKs should not throw in normal operation; unavailable flags usually produce `undefined` / `false` depending on cache state.
- Server SDKs generally swallow evaluation/network errors and return `undefined` / `None`, stale cached values, or other SDK-specific fallbacks rather than crashing application code.
- `$feature_flag_called` tracking failures should not affect the returned flag value.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned value reflects the currently cached flags at the instant of the call.
- If a reload is racing, callers may observe either the old or newly-refreshed value depending on ordering.
- Server evaluation is per-call and independent, except where SDKs use shared caches or dedupe maps for flag-called events.

## Interactions

- **`reload-feature-flags`** — refreshes the client-side cache that this method reads.
- **`is-feature-enabled`** — boolean wrapper over the value returned here; variant strings are treated as enabled.
- **`get-feature-flag-payload`** — returns the payload associated with this method's matched value.
- **`$feature_flag_called`** — many SDKs emit this analytics event when this method is called.
- **`identify` / `group` / person/group-properties-for-flags setters** — can change the context used for subsequent evaluations, often followed by an automatic flag reload on client SDKs.

## Requirements

### Requirement: Canonical get-feature-flag behavior

The SDK SHALL implement the canonical `get-feature-flag` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client getter returns the cached boolean flag value (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value |
  | beta-ui  | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the returned feature flag value should be true
- **AND** a "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"

#### Scenario: Getter returns a variant string for multivariate flags (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value |
  | checkout | blue  |
- **WHEN** get feature flag "checkout" is called
- **THEN** the returned feature flag value should be "blue"

#### Scenario: Getter can suppress feature flag called tracking (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called with tracking disabled
- **THEN** the returned feature flag value should be true
- **AND** no event named "$feature_flag_called" should be enqueued

#### Scenario: Server getter evaluates with explicit context (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a flag "beta-ui" rolled out to distinct id "user-123"
- **WHEN** get feature flag "beta-ui" is called for distinct id "user-123"
- **THEN** the returned feature flag value should be true
