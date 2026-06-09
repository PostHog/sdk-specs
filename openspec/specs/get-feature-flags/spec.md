# Get Feature Flags Specification

## Purpose

`get-feature-flags` returns the **full set of currently known feature-flag values** for a user/context as a key → value map.

This is the bulk counterpart to `get-feature-flag`:

- `get-feature-flag(key)` returns one flag value
- `get-feature-flags()` / `getAllFlags(...)` returns all evaluated flag values at once

Returned values typically use the same representation as single-flag lookups:

- `true` / `false` for boolean flags
- variant strings for multivariate flags

## Applicability

`both` — client and server SDKs both expose a bulk flag-value lookup, but the source of truth differs.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached flag state. | Caller passes `distinct_id` explicitly per call. |
| Data source | Returns the locally cached set of known flag values. | Evaluates all flags locally and/or remotely for the provided user context. |
| Network I/O | Usually none at read time. | May perform remote evaluation or decide/flags calls when local evaluation is insufficient. |
| Missing flags | Only flags known in cache are present. | Returns the full evaluated set; unknown or unavailable flags are typically omitted. |
| Payloads | Not returned by this API. | Not returned by this API; use the paired flags-and-payloads API when needed. |

## Public signatures

### Client-side canonical signature

```ts
getFeatureFlags(): Record<string, boolean | string> | undefined
```

### Server-side canonical signature

```ts
getAllFlags(
  distinct_id: string,
  options?: {
    groups?: Record<string, string>,
    personProperties?: Record<string, unknown>,
    groupProperties?: Record<string, Record<string, unknown>>,
    onlyEvaluateLocally?: boolean,
    disableGeoip?: boolean,
    flagKeys?: string[],
    deviceId?: string,
  },
): Promise<Record<string, boolean | string>> | Record<string, boolean | string>
```

### Surface variants

- **posthog-js core / browser / react-native:** `getFeatureFlags()`
- **Node:** `getAllFlags(distinctId, options?)`
- **Python:** `get_all_flags(distinct_id, *, ...)`
- **Ruby:** `get_all_flags(distinct_id, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false)`
- **PHP:** `getAllFlags(distinctId, groups = [], personProperties = [], groupProperties = [], onlyEvaluateLocally = false)`
- **.NET:** `GetAllFeatureFlagsAsync(distinctId, options?)`

## Behavior

### Client-side flow

1. **Read the cached feature-flag map** from local SDK state.
2. **Return the currently known values as-is.**
3. **Do not fetch from the network directly.** Callers wanting fresh values must reload flags separately.
4. **Do not return payloads.** This API returns only values, not metadata or payloads.

### Server-side flow

1. **Resolve evaluation context** from `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Attempt local evaluation for all flags** when definitions are available.
3. **Fall back to remote evaluation** if local evaluation is unavailable, incomplete, or explicitly bypassed.
4. **Return a key → value map** containing booleans and/or variant strings.
5. **Do not include payloads** in this method's return value; separate APIs return flags and payloads together.

## State & lifecycle

### Client-side state

- Reads from the cached feature-flag state maintained by initialization and `reloadFeatureFlags()`.
- Does not normally mutate state itself.

### Server-side state

- Reads per-call evaluation inputs.
- May read/update local definition caches, stale result caches, or remote evaluation caches indirectly through helper components.

## Error handling

- Client SDKs should not throw in normal operation; if flags are not loaded, they typically return `undefined` or an empty map depending on SDK semantics.
- Server SDKs typically swallow evaluation/network failures and return an empty map or the successfully evaluated subset rather than crashing application code.
- Quota-limited responses often return an empty result map.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned map reflects the cached flags available at the time of the call.
- If a reload is racing, callers may observe either the old or newly-refreshed map.
- Server bulk evaluation is per-call and independent, except where shared caches are consulted.

## Interactions

- **`get-feature-flag`** — single-flag lookup over the same logical value set.
- **`get-feature-flag-payload`** — payload lookup for an individual flag.
- **`get-all-flags-and-payloads` / equivalent** — richer bulk API that also returns payloads.
- **`reload-feature-flags`** — refreshes the client-side cache this method reads.

## Requirements

### Requirement: Canonical get-feature-flags behavior

The SDK SHALL implement the canonical `get-feature-flags` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Bulk getter returns all cached flag values (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
- **WHEN** get feature flags is called
- **THEN** the returned feature flags should be:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |

#### Scenario: Bulk getter evaluates all available flags for explicit context (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include flags:
  | key      | value_for_user_123 |
  | beta-ui  | true               |
  | checkout | blue               |
- **WHEN** get feature flags is called for distinct id "user-123"
- **THEN** the returned feature flags should be:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |

#### Scenario: Bulk getter can suppress tracking events (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flags is called with tracking disabled
- **THEN** no event named "$feature_flag_called" should be enqueued
