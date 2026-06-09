# Feature Flag Called Tracker Specification

## Purpose

`feature-flag-called-tracker` is the internal deduplication component that suppresses duplicate `$feature_flag_called` events for the same flag evaluation outcome.

Its job is to prevent analytics noise when application code repeatedly reads the same flag without the underlying flag value changing.

## Applicability

`both` — audited client and server SDKs use an internal tracker/cache to dedupe `$feature_flag_called` events, though the dedupe key and eviction policy differ.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
shouldTrack(distinctId?, flagKey, value): boolean
markSeen(distinctId?, flagKey, value): void
reset(): void
```

In some SDKs, `shouldTrack` and `markSeen` are combined into one atomic "add if unseen" operation.

## Behavior

1. **Build a dedupe key from the flag access.** Common inputs are:
   - feature flag key
   - evaluated response/value (`true`, `false`, variant string, or `null`/`undefined`)
   - in many server/mobile SDKs, `distinct_id` as well
2. **Check whether this combination was already reported.**
3. **Suppress duplicate tracking events.** If the same combination has already been seen, do not emit another `$feature_flag_called` event.
4. **Allow new tracking when the response changes.** If a flag's value changes for the same key (or for the same user+key, depending on SDK), allow a new `$feature_flag_called` event.
5. **Reset on flag reload/change.** When feature flags are reloaded or caches are reset, clear the dedupe tracker so the next access can emit fresh tracking events.
6. **Expose tracking controls unevenly at the wrapper layer when applicable.** For example, Flutter delegates to the underlying native/browser trackers and only exposes a per-call suppression flag on `getFeatureFlagResult(sendEvent: ...)`, while `getFeatureFlag(...)`, `getFeatureFlagPayload(...)`, and `isFeatureEnabled(...)` always use the default tracking path.
7. **Cap memory usage where needed.** Larger-scale implementations evict old entries using bounded maps or LRU-style caches.

## State & lifecycle

### State read

- in-memory map/LRU cache of previously-reported flag/value combinations

### State written

- newly seen dedupe entries
- tracker reset/eviction state

### Lifecycle behavior

- The tracker starts empty when the SDK initializes.
- Each flag access that would emit `$feature_flag_called` consults the tracker first.
- Flag reloads commonly reset the tracker so new values can be reported again.
- Some SDKs also clear it during identity reset flows because the relevant flag-evaluation context changed.
- Wrapper SDKs may not own a separate tracker at all. Flutter mostly inherits tracker lifecycle from the underlying mobile/browser SDKs it delegates to.

## Error handling

- Tracker operations should not throw in normal operation.
- Missing or uninitialized tracker state should be treated as "nothing seen yet".
- If value serialization/comparison is imperfect, the failure mode should be extra tracking or under-tracking, not application crashes.

## Concurrency & ordering guarantees

- Lookups and updates are synchronized or serialized by the SDK's runtime model.
- Atomic "check and add" behavior is preferred so concurrent accesses do not double-emit the same `$feature_flag_called` event.
- Reset operations take effect immediately for subsequent flag accesses.

## Interactions

- **`get-feature-flag` / `is-feature-enabled` / `get-feature-flag-result`** — all commonly use this tracker before capturing `$feature_flag_called`.
- **`get-feature-flag-payload`** — some SDKs route payload lookups through the same tracking/dedupe machinery, while others suppress tracking or expose only a compatibility wrapper.
- **feature-flag cache reloads** — typically reset the tracker because flag values may have changed.
- **identity resets / context changes** — may also clear the tracker in SDKs where the dedupe key depends on user identity.

## Requirements

### Requirement: Canonical feature-flag-called-tracker behavior

The SDK SHALL implement the canonical `feature-flag-called-tracker` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Tracker emits the first flag-called event for a value
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |

#### Scenario: Tracker suppresses duplicate events for the same flag value
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** get feature flag "beta-ui" is called again
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

#### Scenario: Tracker emits again when the flag value changes
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** cached feature flag "beta-ui" changes to "false"
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"
