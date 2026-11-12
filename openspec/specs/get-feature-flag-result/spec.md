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
- **flutter:** `getFeatureFlagResult(key, { bool? sendFeatureFlagEvent }): Future<PostHogFeatureFlagResult?>` (6.0+; when omitted, falls back to `PostHogConfig.sendFeatureFlagEvent` on iOS, macOS, Android, Windows and Linux, while Web leaves the default to posthog-js); 5.x takes `{ sendEvent = true }`
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
   - Multivariate flag with a non-empty variant → `enabled = true`, `variant = '<variant>'`
   - Empty variant `''` → `enabled = false`, `variant = ''`
   - Payload is attached if available.
3. **Handle missing/unknown flags.** If the SDK cannot determine the flag from cache, return `undefined` / `nil` rather than a partial result object.
4. **Optionally emit `$feature_flag_called`.** In audited client SDKs this is on by default and can be suppressed with a per-call option in some implementations.
5. **Do not fetch from the network directly.** The method uses currently cached flag state; callers wanting fresh data must reload flags separately.

### Server-side flow

1. **Resolve evaluation context** from `distinct_id` plus optional groups, person properties, group properties, device id, and geoip settings.
2. **Evaluate the flag** locally and/or remotely according to SDK configuration.
3. **Construct the result object** from the resolved value and payload.
   - Boolean flag → `enabled = true|false`, `variant = undefined`
   - Multivariate flag with a non-empty variant → `enabled = true`, `variant = '<variant>'`
   - Empty variant `''` → `enabled = false`, `variant = ''`
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

### Requirement: Payload parse failures preserve flag evaluation results

Structured feature flag results SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload`. A malformed payload SHALL be represented as no payload (a language-idiomatic null value or omitted optional payload field), never as its raw serialized string. The SDK MUST NOT discard an otherwise valid flag result or alter its key, enabled state, variant, or valid metadata because payload decoding failed. Value-only and enabled-state APIs that share this result-construction path SHALL preserve the same evaluated flag value and enabled state without throwing. These rules SHALL apply to cached, locally evaluated, and remotely evaluated results.

#### Scenario Outline: Invalid cached payload does not change the flag result (@client)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through client cache with these serialized payload bytes:
  | key      | value   | serialized_payload_json |
  | checkout | <value> | <input>                 |
- **WHEN** get feature flag result "checkout" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | checkout  |
  | enabled | <enabled> |
- **AND** its variant should equal the JSON value <variant> or be absent when null
- **AND** its payload should be absent or the language's no-payload value
- **WHEN** get feature flag "checkout" is called
- **THEN** the returned flag value should equal the JSON value <value>
- **WHEN** is feature enabled "checkout" is called
- **THEN** the returned enabled state should be <enabled>
- **AND** no exception should be thrown

**Examples:**
  | value  | input     | enabled | variant |
  | "blue" | "{broken" | true    | "blue"  |
  | "blue" | ""        | true    | "blue"  |
  | "blue" | "   "     | true    | "blue"  |
  | false  | "{broken" | false   | null    |
  | false  | ""        | false   | null    |
  | false  | "   "     | false   | null    |

#### Scenario Outline: Invalid evaluated payload does not change the flag result (@server)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through <source> with these serialized payload bytes:
  | key      | value   | serialized_payload_json |
  | checkout | <value> | <input>                 |
- **WHEN** get feature flag result "checkout" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | checkout  |
  | enabled | <enabled> |
- **AND** its variant should equal the JSON value <variant> or be absent when null
- **AND** its payload should be absent or the language's no-payload value
- **WHEN** get feature flag "checkout" is called
- **THEN** the returned flag value should equal the JSON value <value>
- **WHEN** is feature enabled "checkout" is called
- **THEN** the returned enabled state should be <enabled>
- **AND** no exception should be thrown

**Examples:**
  | source            | value  | input     | enabled | variant |
  | local evaluation  | "blue" | "{broken" | true    | "blue"  |
  | local evaluation  | "blue" | ""        | true    | "blue"  |
  | local evaluation  | "blue" | "   "     | true    | "blue"  |
  | local evaluation  | false  | "{broken" | false   | null    |
  | local evaluation  | false  | ""        | false   | null    |
  | local evaluation  | false  | "   "     | false   | null    |
  | remote evaluation | "blue" | "{broken" | true    | "blue"  |
  | remote evaluation | "blue" | ""        | true    | "blue"  |
  | remote evaluation | "blue" | "   "     | true    | "blue"  |
  | remote evaluation | false  | "{broken" | false   | null    |
  | remote evaluation | false  | ""        | false   | null    |
  | remote evaluation | false  | "   "     | false   | null    |

### Requirement: Per-call feature flag event option name

A flag-reading API that lets the caller suppress `$feature_flag_called` for that call SHALL name the option `sendFeatureFlagEvent` on client SDKs and `sendFeatureFlagEvents` on server SDKs, adapted to platform casing (for example `send_feature_flag_event`). The singular form governs one call's event; the plural form governs event sending across a server-side evaluation that may emit several. On APIs that return a flag value or result, an omitted option SHALL fall back to the SDK's client-level feature flag event default where the SDK has one, and otherwise SHALL send the event. Payload-only reads keep their silent default (see `get-feature-flag-payload`); the option name still applies there. Per-call names that shipped before this requirement are recorded divergences and are not required to change: posthog-js core and react-native take a per-call `sendEvent` option (`FeatureFlagResultOptions`); their `sendFeatureFlagEvent` is the instance-level client option, not a per-call one. posthog-js browser takes a per-call `send_event` option (`FeatureFlagOptions`). Flutter 5.x takes `getFeatureFlagResult(key, sendEvent:)`; Flutter 6.0 renames it to `sendFeatureFlagEvent`.

#### Scenario: Suppressing the per-call option skips the flag called event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called with the feature flag event option disabled
- **THEN** the returned result value should be true
- **AND** no event named "$feature_flag_called" should be enqueued

#### Scenario: The per-call feature flag event option defaults to sending (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag result "beta-ui" is called without the feature flag event option
- **THEN** the returned result value should be true
- **AND** one event named "$feature_flag_called" should be enqueued

### Requirement: Empty variant reads as disabled

A flag whose value is the empty string `""` SHALL read as disabled. The SDK SHALL return a result with `enabled: false` and `variant: ""`, and `is-feature-enabled` SHALL return `false` for it, whether or not the caller supplies a default.

Known gap: posthog-js core and react-native still return `enabled: true` from `getFeatureFlagResult` for `""`, because `getEnabledFromValue` reads any string as enabled, while their `isFeatureEnabled` returns `false`. A follow-up should make `getFeatureFlagResult` match.

#### Scenario: Empty variant flag result is disabled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | legacy-ui | ""    |
- **WHEN** get feature flag result "legacy-ui" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | legacy-ui |
  | enabled | false     |
- **AND** its variant should equal the JSON value ""
- **WHEN** is feature enabled "legacy-ui" is called
- **THEN** the returned enabled state should be false

### Requirement: Failed remote flag details are not evaluated results

When a direct flag getter consumes a detailed `/flags` response, a per-flag `failed: true` marker SHALL mean that the server produced no evaluated value for that key. The SDK MUST NOT convert that record's `enabled: false` placeholder or its variant into a successful structured result. This rule SHALL apply whether the getter uses remote evaluation directly or falls back from local evaluation, and whether `errorsWhileComputingFlags` is true, false, or absent.

If no successful local or otherwise supported fallback supplies a value for the same evaluation context, `get-feature-flag-result` SHALL return the platform's no-result outcome. The SDK MAY return an idiomatic error alongside that outcome where its public API supports one. Scalar and boolean getters that share this evaluation path SHALL retain their documented no-result/default mappings, including a legacy false sentinel; such a sentinel MUST NOT be treated as a successfully evaluated disabled flag.

When no successful fallback supplies a value, `is-feature-enabled` SHALL honor a caller-supplied default under that capability's existing rules. A legacy false no-result sentinel MUST NOT prevent the caller's default from being used.

The independence from `errorsWhileComputingFlags` concerns interpretation of the incoming record, not client cache retention across refreshes. Client SDKs SHALL continue to follow the `bootstrap` requirement "A complete flags response replaces bootstrapped flags": an intentionally partial or response-wide errored response merges successful values into served state, while a complete response without response-wide errors replaces served state. A per-flag failure alone MUST NOT authorize retaining a previously served value. This does not change preservation of successful same-context local decisions within a server bulk evaluation.

An absent `failed` marker or explicit `failed: false` SHALL NOT by itself invalidate a record. In particular, a healthy boolean false SHALL remain a valid disabled result even when another flag caused response-wide evaluation errors. Legacy response formats without per-flag failure markers SHALL retain their existing value interpretation.

#### Scenario: Failed direct remote evaluation returns no structured result (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback for "checkout"
- **AND** the detailed remote response contains "checkout" with enabled false and failed true
- **WHEN** get feature flag result "checkout" consumes that response
- **THEN** no feature flag result is returned
- **AND** no successful disabled result is manufactured from the placeholder

#### Scenario: Failed remote fallback does not turn an inconclusive local result into false (@server)
- **GIVEN** local evaluation for "checkout" is inconclusive
- **AND** remote fallback is enabled
- **AND** the remote response contains "checkout" with enabled false and failed true
- **WHEN** get feature flag result "checkout" is called for that evaluation context
- **THEN** no feature flag result is returned
- **AND** an idiomatic error returned alongside the no-result outcome remains permitted where documented

#### Scenario Outline: Per-flag failure does not depend on the response-wide error bit (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** a detailed remote response contains "checkout" with failed true
- **AND** errorsWhileComputingFlags is <error_bit>
- **WHEN** get feature flag result "checkout" consumes that response
- **THEN** no feature flag result is returned

**Examples:**
  | error_bit |
  | false     |
  | absent    |

#### Scenario: A healthy disabled sibling remains a valid result (@both)
- **GIVEN** a detailed remote response reports errorsWhileComputingFlags true
- **AND** "checkout" has enabled false and failed true
- **AND** "beta-ui" has enabled false with its failed marker absent or false
- **WHEN** get feature flag result "beta-ui" consumes that response
- **THEN** a feature flag result with key "beta-ui" and enabled false is returned

#### Scenario Outline: Caller defaults distinguish a failed flag from a healthy false (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback for "checkout"
- **AND** its detailed remote record has enabled false and failed <failed>
- **WHEN** is feature enabled "checkout" is called with default value true
- **THEN** the returned enabled value is <enabled>

**Examples:**
  | failed | enabled |
  | true   | true    |
  | false  | false   |

#### Scenario Outline: Client merge refreshes retain a previously served successful value (@client)
- **GIVEN** a client SDK serves "checkout" as true for the current identity
- **AND** its next detailed response has scope <scope> and errorsWhileComputingFlags <error_bit>
- **AND** that response contains "checkout" with enabled false and failed true
- **WHEN** the response refreshes served flags and get feature flag result "checkout" is called for the same identity
- **THEN** the returned result has enabled true from the previously served value

**Examples:**
  | scope               | error_bit |
  | all flags           | true      |
  | an explicit subset  | false     |

#### Scenario Outline: A complete client refresh does not retain a failed key (@client)
- **GIVEN** a client SDK serves "checkout" as true for the current identity
- **AND** its next detailed response is unscoped and errorsWhileComputingFlags is <error_bit>
- **AND** that response contains "checkout" with enabled false and failed true
- **AND** no independent successful fallback supplies a value
- **WHEN** the response refreshes served flags and get feature flag result "checkout" is called
- **THEN** no feature flag result is returned
- **AND** the previously served true value is not retained

**Examples:**
  | error_bit |
  | false     |
  | absent    |

