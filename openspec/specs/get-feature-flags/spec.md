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
- **iOS (4.0+), Android (4.0+), flutter (6.0+):** `getAllFeatureFlags()` returns a list of flag result objects (key, enabled, variant, payload), or `null` when flags are unavailable, instead of a key-to-value map. Each entry matches `getFeatureFlagResult` for that key, so an empty variant reads as disabled. It never sends `$feature_flag_called`.
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

### Requirement: Flag result list reads an empty variant as disabled

On SDKs where `getAllFeatureFlags()` returns a list of flag result objects (iOS 4.0+, Android 4.0+, Flutter 6.0+, KMP), each entry SHALL match what `get-feature-flag-result` returns for that key. A flag whose value is the empty string `""` SHALL stay in the list with `enabled: false` and `variant: ""`. SDKs that return a key → value map keep reporting `""`, as `get-feature-flag` does.

#### Scenario: Flag result list reads an empty variant as disabled (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | beta-ui   | true  |
  | legacy-ui | ""    |
- **WHEN** get all feature flag results is called
- **THEN** the returned feature flag results should include:
  | key       | enabled |
  | beta-ui   | true    |
  | legacy-ui | false   |
- **AND** the returned feature flag result for "legacy-ui" should have variant equal to the JSON value ""

### Requirement: Bulk flag values exclude failed remote decisions

When a bulk flag getter consumes a detailed `/flags` response, it SHALL omit values from records marked `failed: true`, rather than expose their enabled/variant placeholders. A key with no other successfully evaluated value for the same evaluation context SHALL be absent from the returned map or result list. Successfully evaluated siblings, including boolean false, SHALL remain available even when the response reports `errorsWhileComputingFlags`.

When remote fallback supplements local evaluation, a failed remote record MUST NOT overwrite or delete a successful local decision for that key and the same evaluation context. This includes local true, false, and variant-string decisions. Successful remote records SHALL retain the API's existing merge precedence. These rules SHALL also apply when an SDK performs the same bulk local/remote value merge for automatic capture enrichment; this does not require an SDK to add such enrichment.

#### Scenario: Remote-only bulk lookup omits only failed values (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback values
- **AND** a detailed remote response reports errorsWhileComputingFlags true with these records:
  | key        | enabled | variant | failed |
  | checkout   | false   | null    | true   |
  | beta-ui    | true    | null    | false  |
  | disabled   | false   | null    | absent |
  | experiment | true    | blue    | absent |
- **WHEN** the bulk flag getter consumes that response
- **THEN** "checkout" is absent from the returned flags
- **AND** "beta-ui" is present with value true
- **AND** "disabled" is present with value false
- **AND** "experiment" is present with value "blue"

#### Scenario: An all-failed response returns no bulk decisions (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback values
- **AND** every record in its detailed remote response is marked failed true
- **WHEN** the bulk flag getter consumes that response
- **THEN** the returned flag map or result list is empty

#### Scenario: Failed fallback preserves local decisions (@server)
- **GIVEN** local evaluation successfully resolves "enabled-local" to true, "disabled-local" to false, and "variant-local" to "blue" for one evaluation context
- **AND** local evaluation for "checkout" is inconclusive and triggers remote fallback
- **AND** the fallback response marks all four keys failed true with enabled false placeholders
- **WHEN** the bulk flag getter combines the results
- **THEN** "enabled-local" is present with value true
- **AND** "disabled-local" is present with value false
- **AND** "variant-local" is present with value "blue"
- **AND** "checkout" is absent

#### Scenario: Automatic capture enrichment does not attach failed placeholders (@server)
- **GIVEN** the SDK supports automatic bulk flag enrichment during capture and it is enabled
- **AND** local evaluation resolves "beta-ui" to true for the event's evaluation context
- **AND** an inconclusive "checkout" triggers remote fallback
- **AND** the fallback response marks both keys failed true with enabled false placeholders
- **WHEN** a public capture call evaluates and enriches an event for that context
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received event has "$feature/beta-ui" true
- **AND** the received event has no "$feature/checkout" property
