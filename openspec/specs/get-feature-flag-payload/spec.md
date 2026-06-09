# Get Feature Flag Payload Specification

## Purpose

`get-feature-flag-payload` returns the payload associated with a feature flag's matched value.

Payloads are arbitrary JSON values attached to feature flags in PostHog. This API is used after, or alongside, `get-feature-flag` / `is-feature-enabled` when callers need the configuration data for the matched variant rather than just the boolean/variant result.

## Applicability

`both` — client and server SDKs both expose payload lookup, but they get the payload from different sources.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached flag state. | Caller passes `distinct_id` explicitly per call. |
| Data source | Reads payloads from the locally cached feature-flag response. | Evaluates the flag locally and/or remotely, then returns the payload for the matched value. |
| Network I/O | Usually none at read time. | May perform remote evaluation depending on SDK/configuration. |
| Event tracking | Usually **does not** send `$feature_flag_called` when fetching payload only. | Usually also suppresses `$feature_flag_called` on payload-only access, or treats event sending as deprecated/no-op. |
| Optional match value | Usually not needed; payload comes from the cached matched flag. | Some SDKs accept an optional `matchValue` / `override_match_value` to fetch the payload for a known value without recomputing it. |

## Public signatures

### Client-side canonical signature

```ts
getFeatureFlagPayload(key: string): JsonValue | null | undefined
```

### Server-side canonical signature

```ts
getFeatureFlagPayload(
  key: string,
  distinct_id: string,
  matchValue?: boolean | string,
  options?: {
    groups?: Record<string, string>,
    personProperties?: Record<string, unknown>,
    groupProperties?: Record<string, Record<string, unknown>>,
    onlyEvaluateLocally?: boolean,
    sendFeatureFlagEvents?: boolean,
    disableGeoip?: boolean,
    deviceId?: string,
  },
): Promise<JsonValue | null | undefined> | JsonValue | null | undefined
```

### Surface variants

- **posthog-js core / browser / react-native:** `getFeatureFlagPayload(key)`
- **flutter:** `getFeatureFlagPayload(key): Future<Object?>`
- **iOS:** `getFeatureFlagPayload(_ key: String)`
- **Android:** `getFeatureFlagPayload(key, defaultValue = null)`
- **Node:** `await getFeatureFlagPayload(key, distinctId, matchValue?, options?)`
- **Python:** `get_feature_flag_payload(key, distinct_id, *, match_value=None, groups=None, person_properties=None, group_properties=None, only_evaluate_locally=False, send_feature_flag_events=False, disable_geoip=None, device_id=None)`
- **Ruby:** `get_feature_flag_payload(key, distinct_id, match_value: nil, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false)`

## Behavior

### Client-side flow

1. **Read the cached flag result** for the requested key from the SDK's local feature-flag cache.
2. **Extract the payload** associated with the current matched value.
3. **Parse serialized payloads if necessary.** Some SDKs store payloads as JSON strings in cache and parse them on read before returning them.
4. **Do not send `$feature_flag_called` by default.** Payload-only reads are generally treated as non-tracking lookups.
5. **Return a tri-state result:**
   - payload value when present
   - `null` when the flag is known but has no payload (or SDK uses `null` as the “known but empty” sentinel)
   - `undefined` / `nil` when the flag state is unavailable, not yet loaded, or the SDK cannot determine a result

### Server-side flow

1. **Resolve evaluation context** from `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Determine the match value** for the flag.
   - If `matchValue` / `match_value` is supplied, use it.
   - Otherwise evaluate the flag locally and/or remotely to determine the matched value.
3. **Resolve the payload** for that value.
4. **Suppress flag-called tracking by default** for payload-only reads in audited server SDKs.
5. **Return:**
   - payload value when present
   - `null` when the flag exists but has no payload (SDK-dependent)
   - `undefined` / `None` when the flag is missing, unavailable, or evaluation failed

## State & lifecycle

### Client-side state

- Reads from the cached feature-flag payload store populated by initialization and `reloadFeatureFlags()`.
- Does not normally mutate identity or flag state.
- May parse payload JSON lazily on read.

### Server-side state

- Reads per-call evaluation inputs.
- May read local flag-definition caches, stale per-user result caches, or remote evaluation results.
- Does not usually mutate `$feature_flag_called` bookkeeping because payload-only calls typically suppress tracking.

## Error handling

- Client SDKs should not throw in normal operation; missing/unavailable payloads return `null` / `undefined` depending on SDK.
- Server SDKs typically swallow evaluation/network failures and return `undefined` / `None` or stale fallback-derived payloads rather than crashing application code.
- Payload parsing failures are logged and treated as missing/unparsed payloads rather than being thrown to the caller.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned payload reflects the cached flag state available at the instant of the call.
- If a reload is racing, callers may observe either the old or the newly-refreshed payload.
- Server evaluation is per-call and independent, except where SDKs use shared local caches.

## Interactions

- **`get-feature-flag`** — provides the raw matched value whose payload this method returns.
- **`is-feature-enabled`** — boolean wrapper used when callers only care whether a feature is on, not the payload.
- **`reload-feature-flags`** — refreshes the client-side payload cache that this method reads.
- **`$feature_flag_called`** — usually *not* emitted for payload-only reads; callers wanting tracking should use `get-feature-flag` / `getFeatureFlagResult` where appropriate.

## Requirements

### Requirement: Canonical get-feature-flag-payload behavior

The SDK SHALL implement the canonical `get-feature-flag-payload` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Payload getter returns payload for the matched flag value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value | payload                |
  | checkout | blue  | {"cta":"Try now"}   |
- **WHEN** get feature flag payload "checkout" is called
- **THEN** the returned payload should include:
  | field | value   |
  | cta   | Try now |

#### Scenario: Payload getter returns no payload for unknown flags (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are empty
- **WHEN** get feature flag payload "missing-flag" is called
- **THEN** no payload should be returned
- **AND** no exception should be thrown

#### Scenario: Payload lookup does not emit feature flag called by itself (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value | payload        |
  | checkout | true  | {"enabled":1} |
- **WHEN** get feature flag payload "checkout" is called
- **THEN** no event named "$feature_flag_called" should be enqueued
