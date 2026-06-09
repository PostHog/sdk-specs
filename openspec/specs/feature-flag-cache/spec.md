# Feature Flag Cache Specification

## Purpose

`feature-flag-cache` is the internal store that holds the SDK's most recently known feature-flag state so flag lookups can be served without re-fetching from the network every time.

It typically stores, at minimum:

- raw flag values (`true` / `false` / variant string)
- flag payloads
- richer flag metadata/details when the backend returns them
- request metadata such as `request_id` / `evaluated_at`

This component is what powers client-side `getFeatureFlag(...)`, `isFeatureEnabled(...)`, `getFeatureFlagPayload(...)`, and `getFeatureFlagResult(...)` after initialization or a reload.

## Applicability

`client` — this spec covers the client-side cache for feature-flag state. Some server SDKs also cache flag definitions or results, but the audited implementations here are the ambient caches used by client SDKs and mobile-style wrappers.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
loadFromStorage(): void | CachedFlags | undefined
getFlag(key): FeatureFlagValue | undefined
getPayload(key): JsonLike | undefined
getDetails(key): FeatureFlagDetail | undefined
updateFromResponse(response): void
clear(): void
```

## Behavior

1. **Load cached flags lazily or at startup.** The cache may be populated from persisted storage on initialization, or lazily on first flag access.
2. **Store multiple representations of the same flag state.** Mature implementations often retain:
   - simplified `featureFlags` map for quick lookups
   - `featureFlagPayloads` map for payload lookups
   - richer `flags` / metadata entries for id/version/reason/payload access
3. **Normalize server responses before caching.** When the API response shape differs by backend version (for example legacy vs. richer V4 details), the cache normalizes it into a stable local format.
4. **Serve flag reads from local memory first.** `getFlag`, `getPayload`, and `getDetails` should be cheap, local reads.
5. **Allow wrapper SDKs to delegate to an underlying cache instead of owning a second one.** Flutter's Dart layer forwards flag reads to the native/browser SDKs' caches rather than maintaining an independent Dart-side feature-flag store.
6. **Persist updated cache state.** After successful reloads, the cache writes the normalized values back to persistent storage so they survive restarts.
7. **Handle partial responses carefully.** If the backend reports "errors while computing flags," some SDKs merge successful keys into the existing cache instead of replacing everything.
8. **Handle quota-limited / empty states explicitly.** When the backend indicates quota limiting or "no active flags," implementations either preserve prior details with an error marker or clear the cached flags, depending on SDK semantics.
9. **Support cache clearing.** Reset flows and explicit clear operations remove cached flags/payloads/details and associated request metadata.
10. **Parse payloads lazily if stored as strings.** Some SDKs persist payloads as raw strings and only JSON-decode them when callers request the payload/result.
11. **Emit/update listener-facing state when the cache changes.** Higher-level components often notify listeners after a successful cache update.

## State & lifecycle

### State read

- persisted flag values / payloads / details
- persisted request metadata (`request_id`, `evaluated_at`)
- optional bootstrapped/override flag state layered on top of cached values

### State written

- cached feature flags
- cached feature flag payloads
- cached rich flag details
- request metadata / evaluation timestamps
- listener-facing derived state (through higher layers)

### Lifecycle behavior

- Cache is empty before first successful load unless bootstrap or persisted state exists.
- Reload/update operations replace or merge cache contents.
- `reset()` or dedicated clear paths remove cached flags.
- Some SDKs preserve cached flags across process restarts by writing them to disk/state storage.
- Wrapper SDKs may surface cache updates through callbacks instead of exposing the cache directly. Flutter wires `onFeatureFlags` to Android/iOS native notifications and browser `posthog.onFeatureFlags(...)`, while continuing to read values from the underlying platform caches.

## Error handling

- Cache read/write failures are logged and treated as recoverable.
- Invalid payload JSON is logged and returned as the raw value or treated as absent, rather than throwing.
- Missing keys return `undefined` / `nil` / `null` according to the caller API contract.
- Partial or quota-limited responses are reflected in cache state without crashing application code.

## Concurrency & ordering guarantees

- Cache mutation is synchronized by locks or serialized runtime execution.
- Reads during an in-flight reload may observe either the previous cache contents or the updated cache, but not a torn partial structure.
- Request metadata and flag maps are generally updated as one logical cache write per response.

## Interactions

- **`reload-feature-flags`** fetches fresh data and updates this cache.
- **feature-flag getter APIs** (`get-feature-flag`, `is-feature-enabled`, `get-feature-flag-payload`, `get-feature-flag-result`) read from this cache.
- **persistent storage** backs durable cached flags across restarts.
- **override/bootstrap mechanisms** may layer extra values over the stored cache when serving reads.
- **wrapper-layer callbacks** such as Flutter's `onFeatureFlags` can observe cache updates even when the wrapper does not own the cache itself.
- **remote-config/session-replay integrations** sometimes depend on the same response that updates the flag cache.

## Requirements

### Requirement: Canonical feature-flag-cache behavior

The SDK SHALL implement the canonical `feature-flag-cache` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Cache stores flag values and payloads from a successful load
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** feature flags are loaded with values:
  | key     | value | payload              |
  | beta-ui | true  | {"color":"green"} |
- **THEN** cached feature flags should include:
  | key     | value |
  | beta-ui | true  |
- **AND** cached feature flag payloads should include:
  | key     | payload              |
  | beta-ui | {"color":"green"} |

#### Scenario: Cache serves reads without a network request
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the returned feature flag value should be true
- **AND** no feature flag network request should be sent

#### Scenario: Cache is cleared on identity reset when user-scoped flags are invalidated
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** reset is called
- **THEN** cached feature flags should be empty
