# Get Feature Flags And Payloads Specification

## Purpose

`get-feature-flags-and-payloads` returns the current feature-flag values **and** their payloads together in one call.

It exists to avoid separate per-flag lookups when callers need a bulk snapshot of:

- all flag values
- all payloads associated with those values

This is the bulk companion to `get-feature-flag-result` and the combined form of `get-feature-flags` + `get-feature-flag-payload`.

## Applicability

`both` — client and server SDKs can expose a bulk flags+payloads view, though the source of truth differs.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Identity source | Uses the SDK's current ambient identity and cached flag state. | Caller passes `distinct_id` explicitly per call. |
| Data source | Reads from the locally cached flag/payload state. | Evaluates locally and/or remotely for the provided context. |
| Network I/O | Usually none at read time. | May perform remote evaluation or fallback-to-decide/flags requests. |
| Result shape | Usually `{ flags, payloads }`. | Usually `{ featureFlags, featureFlagPayloads }` or a closely-related pair of maps. |

## Public signatures

### Canonical signature

```ts
getFeatureFlagsAndPayloads(
  distinctId?: string,
  options?: {
    groups?: Record<string, string>,
    personProperties?: Record<string, unknown>,
    groupProperties?: Record<string, Record<string, unknown>>,
    onlyEvaluateLocally?: boolean,
    disableGeoip?: boolean,
    flagKeys?: string[],
    deviceId?: string,
  },
):
  | { flags: Record<string, boolean | string> | undefined; payloads: Record<string, unknown> | undefined }
  | Promise<{ flags?: Record<string, boolean | string>; payloads?: Record<string, unknown> }>
```

### Surface variants

- **posthog-js core / browser / react-native:** `getFeatureFlagsAndPayloads()` → `{ flags, payloads }`
- **Node:** `getAllFlagsAndPayloads(distinctId, options?)` → `{ featureFlags, featureFlagPayloads }`
- **Python:** `get_all_flags_and_payloads(distinct_id, *, ...)` → `{ featureFlags, featureFlagPayloads }`
- **Ruby:** `get_all_flags_and_payloads(distinct_id, groups: {}, person_properties: {}, group_properties: {}, only_evaluate_locally: false)` → `{ featureFlags, featureFlagPayloads, ... }`

Some SDKs do not expose this exact paired bulk API and instead return richer per-flag objects from `GetAllFeatureFlagsAsync(...)` or require separate flag/payload calls.

## Behavior

### Client-side flow

1. **Read the cached flag values map** from local SDK state.
2. **Read the cached payloads map** from local SDK state.
3. **Return both together** without performing network I/O.
4. **Do not emit `$feature_flag_called` events directly.** This is a bulk cache read.

### Server-side flow

1. **Resolve evaluation context** from `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Attempt local evaluation** of all requested flags when definitions are available.
3. **Collect values and payloads** from the local evaluation result.
4. **Fall back to remote evaluation** if local evaluation is unavailable, incomplete, or explicitly bypassed.
5. **Return both maps together** in one result object.

## State & lifecycle

### State read

- cached flag values
- cached payload values
- local definition/evaluation state for server-side local evaluation
- per-call identity and properties on server SDKs

### State written

Usually none directly, though server-side evaluation paths may update caches indirectly via their helper components.

### Lifecycle behavior

- On client SDKs, this method reflects the most recently loaded flag cache.
- On server SDKs, this method reflects the evaluation context of the specific call.
- Callers wanting fresh client-side values must use `reload-feature-flags` first.

## Error handling

- Client SDKs should not throw in normal operation; unloaded caches usually return `undefined` or empty maps.
- Server SDKs generally swallow evaluation/network failures and return empty maps or partial successful results rather than crashing application code.
- Payload parse issues are handled inside the cache/evaluator layers and should not break the combined result shape.

## Concurrency & ordering guarantees

- Client reads are lock-protected or event-loop serialized.
- The returned maps represent a single snapshot of the currently known cache state.
- If a reload/evaluation is racing, callers may observe either the previous or newly-updated state.
- Server bulk evaluation is per-call and independent, subject to shared definition caches.

## Interactions

- **`get-feature-flags`** — value-only subset of this API.
- **`get-feature-flag-payload`** — per-flag payload lookup using the same underlying data.
- **`get-feature-flag-result`** — richer per-flag combined result.
- **`reload-feature-flags`** — refreshes the client-side cache this API reads.
## Requirements
### Requirement: Canonical get-feature-flags-and-payloads behavior

The SDK SHALL implement the canonical `get-feature-flags-and-payloads` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Bulk getter returns flags and payloads together (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value | payload               |
  | beta-ui  | true  | {"color":"green"} |
  | checkout | blue  | {"copy":"new"}    |
- **WHEN** get feature flags and payloads is called
- **THEN** the returned feature flag values should be:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
- **AND** the returned feature flag payloads should be:
  | key      | payload             |
  | beta-ui  | {"color":"green"} |
  | checkout | {"copy":"new"}    |

#### Scenario: Bulk values and payloads are empty when no flags are known (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are empty
- **WHEN** get feature flags and payloads is called
- **THEN** the returned feature flag values should be empty
- **AND** the returned feature flag payloads should be empty

### Requirement: Bulk payload decoding agrees with single-flag APIs

Bulk flags-and-payloads APIs SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload` for each payload independently. Malformed, empty, or whitespace-only serialized payloads SHALL be treated as missing: the affected payload entry SHALL be omitted or contain the language's no-payload value according to the SDK's existing missing-payload map convention, never the raw string. A payload decoding failure MUST NOT discard the associated flag value, healthy sibling payloads, or the combined result. These rules SHALL apply to client caches and server local and remote evaluation paths.

#### Scenario: Bulk results isolate malformed payloads (@both)
- **GIVEN** flag "checkout" has value "blue" and serialized payload `{broken`
- **AND** flag "beta-ui" has value true and serialized payload `{"color":"green"}`
- **WHEN** get feature flags and payloads is called
- **THEN** both flag values are returned unchanged
- **AND** "checkout" has no payload entry or a language-idiomatic no-payload value
- **AND** "beta-ui" has decoded payload `{"color":"green"}`
- **AND** no raw malformed string is returned and no exception is thrown

#### Scenario: Empty serialized payload agrees across single and bulk reads (@both)
- **GIVEN** a known flag has an empty serialized payload
- **WHEN** its payload is read individually and through the bulk flags-and-payloads API
- **THEN** both APIs treat its payload as missing
- **AND** the bulk result retains its evaluated flag value

#### Scenario: Valid JSON empty string is preserved in bulk (@both)
- **GIVEN** a known flag has serialized payload `""`
- **WHEN** its payload is read individually and through the bulk flags-and-payloads API
- **THEN** both APIs return the decoded empty string as its payload
